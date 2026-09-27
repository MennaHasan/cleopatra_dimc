// End-to-end regression: real HWPE register writes, HCI memory requests and
// full row-major matrices. No direct datapath stimulus or pre-tiled files.
`timescale 1ns/1ps
package tb_dimc_memory;
  byte unsigned mem [0:262143];
endpackage

// Simulation-only shared memory port. Requests can queue, grants can stall,
// responses have ordered variable latency and remain stable under backpressure.
// Stores commit at the grant edge (the HCI sink's completion contract).
module tb_dimc_memory_port #(
  parameter int DW=256, SALT=0,
  parameter bit WRITE_PORT=0
)(
  input logic clk_i, rst_ni, stalls_i,
  input logic [31:0] region_base_i, region_bytes_i,
  hci_core_intf.target port,
  output int transfers_o
);
  import tb_dimc_memory::*;
  typedef struct packed {logic [DW-1:0] data; logic id; int due;} response_t;
  response_t queue_ [0:7];
  int read_ptr=0, write_ptr=0, queued=0;
  response_t entry;
  int cycle=0;
  logic waiting;
  logic [DW-1:0] saved_data;
  logic [31:0] saved_addr;
  logic [DW/8-1:0] saved_be;
  logic saved_wen;
  logic accepted, consumed;
  assign port.gnt = rst_ni && port.req && queued<8 &&
                    (!stalls_i || (cycle+SALT)%5 != 0);
  assign port.r_valid = rst_ni && queued>0 && queue_[read_ptr].due <= cycle;
  assign port.r_data = queued>0 ? queue_[read_ptr].data : '0;
  assign port.r_id = queued>0 ? queue_[read_ptr].id : '0;
  assign port.r_user='0;
  assign port.r_opc=0;
  assign port.r_ecc='0;
  assign port.egnt='0;
  assign port.r_evalid='0;
  always @(posedge clk_i) begin
    if (!rst_ni) begin
      read_ptr=0; write_ptr=0; queued=0; cycle=0; transfers_o=0; waiting=0;
    end else begin
      // Check request stability through grant stalls, including during abort.
      if (waiting)
        assert (port.req && port.add===saved_addr && port.data===saved_data &&
                port.be===saved_be && port.wen===saved_wen)
          else $fatal(1, "Memory request changed while stalled");
      waiting = port.req && !port.gnt;
      saved_addr=port.add; saved_data=port.data; saved_be=port.be; saved_wen=port.wen;
      accepted = port.req && port.gnt;
      consumed = port.r_valid && port.r_ready;
      // All clocked DUT blocks sample first. Then update this simulation model
      // in the inactive region, before the interface's delayed assertions.
      // saved_* holds the request that was actually accepted at the edge.
      #0;
      if (consumed) begin
        read_ptr=(read_ptr+1)%8; queued--;
      end
      if (accepted) begin
        assert (saved_addr >= region_base_i &&
                64'(saved_addr)+DW/8 <= 64'(region_base_i)+region_bytes_i)
          else $fatal(1, "Memory access outside matrix: address=%h base=%h bytes=%0d", saved_addr, region_base_i, region_bytes_i);
        assert (saved_wen == !WRITE_PORT) else $fatal(1, "Wrong memory direction");
        transfers_o++;
        if (saved_wen) begin
          for (int b=0;b<DW/8;b++) entry.data[b*8 +: 8]=mem[saved_addr+b];
          entry.id=port.id;
          entry.due=cycle+1+(stalls_i ? (cycle+SALT)%7 : 0);
          queue_[write_ptr]=entry;
          write_ptr=(write_ptr+1)%8; queued++;
        end else begin
          assert (&saved_be) else $fatal(1, "Unexpected partial result write");
          for (int b=0;b<DW/8;b++) if (saved_be[b]) mem[saved_addr+b]=saved_data[b*8 +: 8];
        end
      end
      cycle <= cycle+1;
    end
  end
endmodule

module tb_dimc_top;
  import dimc_package::*;
  import tb_dimc_memory::*;
  logic clk=0;
  always #5ns clk=~clk;
  logic rst_n=0, stalls=0, busy;
  logic [1:0][1:0] evt;
  hwpe_ctrl_intf_periph #(.ID_WIDTH(10)) periph (.clk(clk));
  hci_core_intf #(.DW(64), .IW(1), .EW(0), .EHW(0)) input_mem (.clk(clk));
  hci_core_intf #(.DW(256), .IW(1), .EW(0), .EHW(0)) weight_mem (.clk(clk));
  hci_core_intf #(.DW(256), .IW(1), .EW(0), .EHW(0)) output_mem (.clk(clk));
  dimc_top i_dut (
    .clk_i(clk), .rst_ni(rst_n), .test_mode_i(1'b0), .busy_o(busy), .evt_o(evt),
    .periph, .input_tcdm(input_mem), .kernel_tcdm(weight_mem), .output_tcdm(output_mem)
  );
  localparam int WBASE='h1000, IBASE='h11000, OBASE='h14000;
  logic [31:0] weight_bytes, input_bytes, output_bytes;
  int input_count, weight_count, output_count, done_count=0;
  tb_dimc_memory_port #(.DW(64), .SALT(1)) i_input_memory (
    .clk_i(clk), .rst_ni(rst_n), .stalls_i(stalls), .port(input_mem),
    .region_base_i(32'(IBASE)), .region_bytes_i(input_bytes), .transfers_o(input_count)
  );
  tb_dimc_memory_port #(.DW(256), .SALT(2)) i_weight_memory (
    .clk_i(clk), .rst_ni(rst_n), .stalls_i(stalls), .port(weight_mem),
    .region_base_i(32'(WBASE)), .region_bytes_i(weight_bytes), .transfers_o(weight_count)
  );
  tb_dimc_memory_port #(.DW(256), .SALT(3), .WRITE_PORT(1)) i_output_memory (
    .clk_i(clk), .rst_ni(rst_n), .stalls_i(stalls), .port(output_mem),
    .region_base_i(32'(OBASE)), .region_bytes_i(output_bytes), .transfers_o(output_count)
  );
  logic [7:0] weights [0:49151], inputs [0:6143];
  logic [31:0] golden [0:2047];
  always @(negedge clk) if (evt[0][0]) done_count++;
  always @(posedge clk) if ($test$plusargs("TRACE_CONFIG") && i_dut.i_ctrl.slave_flags.start)
    $display("CONFIG valid=%b dims=%d,%d,%d,%d addr=%h,%h,%h mode=%b ends=%h,%h,%h",
      i_dut.i_ctrl.valid_config, i_dut.i_ctrl.programmed.weight_rows,
      i_dut.i_ctrl.programmed.weight_cols, i_dut.i_ctrl.programmed.input_rows,
      i_dut.i_ctrl.programmed.input_cols, i_dut.i_ctrl.programmed.kernel_addr,
      i_dut.i_ctrl.programmed.input_addr, i_dut.i_ctrl.programmed.output_addr,
      i_dut.i_ctrl.programmed.mode, i_dut.i_ctrl.weight_end,
      i_dut.i_ctrl.input_end, i_dut.i_ctrl.output_end);

  // One software bus operation. HWPE-Ctrl uses wen=0 for writes, wen=1 reads.
  task automatic access(input bit read_, input int addr, input logic [31:0] data,
                        output logic [31:0] response);
    @(negedge clk);
    periph.req=1; periph.wen=read_; periph.add=addr; periph.data=data;
    do @(posedge clk); while (!periph.gnt);
    @(negedge clk);
    periph.req=0;
    while (!periph.r_valid) @(negedge clk);
    response=periph.r_data;
  endtask
  task automatic wr(input int addr, input logic [31:0] data);
    logic [31:0] ignored;
    access(0,addr,data,ignored);
  endtask
  task automatic reg_write(input int reg_index, input logic [31:0] data);
    wr(DIMC_IO_BASE+4*reg_index,data);
  endtask
  task automatic configure(input int nk,nl,nq, input int sign_mode=0, bias=0);
    logic [31:0] acquired;
    access(1,'h04,0,acquired);
    assert (!acquired[31]) else $fatal(1,"Cannot acquire HWPE context");
    reg_write(DIMC_REG_INPUT_ADDR,IBASE);
    reg_write(DIMC_REG_KERNEL_ADDR,WBASE);
    reg_write(DIMC_REG_OUTPUT_ADDR,OBASE);
    reg_write(DIMC_REG_WEIGHT_ROWS,nk*32);
    reg_write(DIMC_REG_WEIGHT_COLS,nl*128);
    reg_write(DIMC_REG_INPUT_ROWS,nl*128);
    reg_write(DIMC_REG_INPUT_COLS,nq*8);
    reg_write(DIMC_REG_FORMAT,3 | (sign_mode<<2));
    reg_write(DIMC_REG_BIAS,bias);
    reg_write(DIMC_REG_COMPUTE_MASK,0);
    for (int i=0;i<8;i++) reg_write(DIMC_REG_WRITE_MASK+i,'1);
  endtask

  // Store the selected matrices contiguously, row-major, in simulated memory.
  // File strides remain 384 and 16, while memory strides use this job's sizes.
  task automatic fill_memory(input int nk,nl,nq);
    weight_bytes=nk*32*nl*128;
    input_bytes=nl*128*nq*8;
    output_bytes=nk*32*nq*8*4;
    for (int r=0;r<nk*32;r++)
      for (int c=0;c<nl*128;c++) mem[WBASE+r*nl*128+c]=weights[r*384+c];
    for (int r=0;r<nl*128;r++)
      for (int c=0;c<nq*8;c++) mem[IBASE+r*nq*8+c]=inputs[r*16+c];
    for (int b=-32;b<int'(output_bytes)+32;b++) mem[OBASE+b]='ha5;
  endtask

  task automatic check_memory(input int nk,nl,nq, input int sign_mode=0,bias=0);
    logic [31:0] expected, got;
    int w,x;
    for (int r=0;r<nk*32;r++) begin
      for (int c=0;c<nq*8;c++) begin
        expected=32'(nl*bias); // Cleopatra applies ADDIN once per inner tile.
        for (int n=0;n<nl*128;n++) begin
          w=int'(weights[r*384+n]); x=int'(inputs[n*16+c]);
          if ((sign_mode&1)!=0 && w>=128) w-=256;
          if ((sign_mode&2)!=0 && x>=128) x-=256;
          expected+=32'(w*x);
        end
        for (int b=0;b<4;b++) got[b*8 +: 8]=mem[OBASE+4*(r*nq*8+c)+b];
        assert (got === expected)
          else $fatal(1,"Result [%0d,%0d] got=%h expected=%h",r,c,got,expected);
        if (nl==3 && sign_mode==0 && bias==0)
          assert (got===golden[r*16+c]) else $fatal(1,"Python golden mismatch");
      end
    end
    for (int b=1;b<=32;b++) begin
      assert (mem[OBASE-b]=='ha5 && mem[OBASE+output_bytes+b-1]=='ha5)
        else $fatal(1,"Output guard bytes overwritten");
    end
  endtask

  task automatic run_job(input int nk,nl,nq, input bit add_stalls,
                         input int sign_mode=0,bias=0);
    int before_done, before_input,before_weight,before_output;
    logic [31:0] status;
    fill_memory(nk,nl,nq); stalls=add_stalls;
    configure(nk,nl,nq,sign_mode,bias);
    before_done=done_count; before_input=input_count;
    before_weight=weight_count; before_output=output_count;
    wr('h00,0); // commit and trigger
    wait(done_count==before_done+1);
    @(negedge clk);
    assert (!busy) else $fatal(1,"Completion signalled before engine idle");
    assert (input_count-before_input==nk*nl*nq*128 &&
            weight_count-before_weight==nk*nl*nq*128 &&
            output_count-before_output==nk*nq*32)
      else $fatal(1,"Incorrect transfer counts: input=%0d weight=%0d output=%0d",
                  input_count-before_input,weight_count-before_weight,output_count-before_output);
    check_memory(nk,nl,nq,sign_mode,bias);
    access(1,'h18,0,status);
    assert (status==0) else $fatal(1,"Unexpected completion status %h",status);
    $display("[DIMC_TOP] PASS K=%0d L=%0d Q=%0d stalls=%0d sign=%0d bias=%0d",
             nk,nl,nq,add_stalls,sign_mode,bias);
  endtask

  initial begin
    periph.req=0; periph.add=0; periph.wen=1; periph.data=0;
    periph.be='1; periph.id=1;
    $readmemh("stimuli/double_buffering/double_buffering_kernel_stim.txt",weights);
    $readmemh("stimuli/double_buffering/double_buffering_feature_stim.txt",inputs);
    $readmemh("stimuli/double_buffering/double_buffering_golden_matmul_output.txt",golden);
    repeat (4) @(negedge clk);
    rst_n=1;
    repeat (8) @(negedge clk);
    run_job(4,3,2,0);
    run_job(4,3,2,1);
    run_job(1,1,1,1);
    run_job(1,2,1,1,3,-7);
    run_job(2,1,2,1);
    // Program the second HWPE context while the first job runs. Different
    // arithmetic configuration proves that queued writes cannot corrupt it.
    begin
      int before_done;
      fill_memory(1,2,1); configure(1,2,1,0,1);
      before_done=done_count;
      wr(0,0);
      wait(busy);
      configure(1,2,1,3,-9);
      wr(0,0);
      wait(done_count==before_done+1);
      @(negedge clk);
      check_memory(1,2,1,0,1);
      wait(done_count==before_done+2);
      @(negedge clk);
      check_memory(1,2,1,3,-9);
      $display("[DIMC_TOP] PASS queued contexts keep independent configuration");
    end
    // Invalid command must complete with error and issue no memory transfers.
    begin
      int before_done, before_requests;
      logic [31:0] status;
      configure(1,1,1);
      reg_write(DIMC_REG_INPUT_ROWS,256); // mismatched inner dimension
      before_done=done_count; before_requests=input_count+weight_count+output_count;
      wr(0,0);
      wait(done_count==before_done+1);
      access(1,'h18,0,status);
      assert (status==2 && before_requests==input_count+weight_count+output_count)
        else $fatal(1,"Invalid command not rejected cleanly");
      $display("[DIMC_TOP] PASS invalid configuration rejection");
    end
    // Abort while memory reads are outstanding; old responses must be drained
    // before software sees busy=0 and starts another job.
    fill_memory(4,3,2); configure(4,3,2); wr(0,0);
    wait(input_mem.req && input_mem.gnt);
    wr('h14,0);
    wait(busy);
    wait(!busy);
    repeat (8) @(negedge clk);
    run_job(1,1,1,1);
    // Abort during a stalled output burst. Complete that burst before reset;
    // then a fresh job must still produce correct results with no stale writes.
    fill_memory(1,1,1); configure(1,1,1); wr(0,0);
    wait(output_mem.req && !output_mem.gnt);
    wr('h14,0);
    wait(busy);
    wait(!busy);
    repeat (8) @(negedge clk);
    run_job(1,1,1,1);
    $display("[DIMC_TOP] PASS abort during output write and restart");
    $display("[DIMC_TOP] ALL TESTS PASSED");
    $finish;
  end
  initial begin
    #5ms;
    $fatal(1,"Full-system test timeout");
  end
endmodule
