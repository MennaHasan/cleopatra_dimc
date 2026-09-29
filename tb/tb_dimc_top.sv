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

// Passive timing instrumentation: this module never drives the RTL. A cycle
// timestamp is taken at each rising edge. Latency = end edge - start edge;
// adjacent edges are one cycle apart (there is no extra inclusive +1).
module tb_dimc_timing_monitor (
  input logic clk_i, rst_ni, enable_i, stalls_i,
  input logic job_start_i, job_done_i,
  input wire dimc_package::dimc_config_t config_i,
  input logic memory_req_i, memory_gnt_i, fifo_push_i, macro_write_i,
  input logic load_macro_i,
  input logic [1:0] feature_load_i, compute_issue_i,
  input logic [1:0][1:0] feature_addr_i,
  input logic [1:0][6:0] compute_addr_i,
  input logic result_pop_i, active_macro_i, output_tile_accept_i
);
  typedef struct packed {
    longint unsigned request_cycle;
    longint unsigned fifo_cycle;
  } section_stamp_t;
  longint unsigned request_times[$];
  section_stamp_t fifo_times[$];
  section_stamp_t stamp;
  longint unsigned cycle=0, start_cycle, request_cycle;
  longint unsigned memory_latency, fifo_latency;
  longint unsigned memory_sum, memory_min, memory_max;
  longint unsigned fifo_sum, fifo_min, fifo_max;
  longint unsigned expected_products, expected_outputs, sections;
  int products, output_tiles, results_in_product, macro_products[0:1];
  bit measuring=0, request_waiting=0;

  typedef struct packed {
    longint unsigned samples, sum, minimum, maximum;
  } latency_stats_t;
  latency_stats_t weight_tile_stats[0:1], vector_stats[0:1], matvec_stats[0:1];
  longint unsigned weight_tile_start[0:1], vector_start[0:1];
  int weight_sections[0:1], vector_sections[0:1];
  typedef struct packed {
    logic macro_id;
    longint unsigned start_cycle;
  } matvec_stamp_t;
  matvec_stamp_t matvec_starts[$], matvec_stamp;

  // Simulation-only helpers for collecting and printing actual edge intervals.
  task automatic add_sample(inout latency_stats_t stats, input longint unsigned latency);
    stats.samples++;
    stats.sum+=latency;
    if (latency<stats.minimum) stats.minimum=latency;
    if (latency>stats.maximum) stats.maximum=latency;
  endtask
  task automatic print_stats(input int macro_id, input string label_, input latency_stats_t stats);
    if (stats.samples>0)
      $display("[TIMING] Macro %0d %s: samples=%0d min=%0d avg=%0.3f max=%0d cycles",
        macro_id,label_,stats.samples,stats.minimum,real'(stats.sum)/real'(stats.samples),stats.maximum);
    else
      $display("[TIMING] Macro %0d %s: samples=0 (no measurement)",macro_id,label_);
  endtask

  always @(posedge clk_i) begin
    if (!rst_ni) begin
      cycle=0;
      measuring=0;
      request_waiting=0;
      request_times.delete();
      fifo_times.delete();
      matvec_starts.delete();
    end else if (enable_i) begin
      cycle++;
      // The datapath accepts start and latches its dimensions on this edge.
      // Software register programming and controller launch overhead precede it.
      if (job_start_i) begin
        assert (!measuring) else $fatal(1,"Timing monitor saw overlapping jobs");
        measuring=1;
        start_cycle=cycle;
        products=0; output_tiles=0; results_in_product=0; sections=0;
        macro_products[0]=0; macro_products[1]=0;
        memory_sum=0; memory_min='1; memory_max=0;
        fifo_sum=0; fifo_min='1; fifo_max=0;
        request_waiting=0;
        request_times.delete(); fifo_times.delete();
        matvec_starts.delete();
        for (int m=0; m<2; m++) begin
          weight_tile_stats[m]='{samples:0, sum:0, minimum:'1, maximum:0};
          vector_stats[m]='{samples:0, sum:0, minimum:'1, maximum:0};
          matvec_stats[m]='{samples:0, sum:0, minimum:'1, maximum:0};
          weight_sections[m]=0; vector_sections[m]=0;
          weight_tile_start[m]=0; vector_start[m]=0;
        end
        expected_outputs=64'(config_i.weight_rows/32)*64'(config_i.input_cols/8);
        expected_products=expected_outputs*64'(config_i.weight_cols/128);
        $display("[TIMING] ONE JOB: weights=%0dx%0d, inputs=%0dx%0d, result=%0dx%0d",
          config_i.weight_rows,config_i.weight_cols,config_i.input_rows,
          config_i.input_cols,config_i.weight_rows,config_i.input_cols);
        $display("[TIMING] Clock=10 ns. Cycle 0 = datapath start accepted; memory stalls=%0d",
          stalls_i);
        $display("[TIMING] Cumulative tile milestones finish when the 256th result is accumulated.");
      end
      if (measuring) begin
        // Timestamp the FIRST sampled assertion of each weight request, before
        // grant. Keep the timestamp through grant stalls. Back-to-back granted
        // requests count separately even when req never goes low.
        if (memory_req_i && !request_waiting) request_times.push_back(cycle);
        request_waiting=memory_req_i && !memory_gnt_i;
        // Responses are ordered on this HCI source. Match each incoming section
        // to its request, then follow it through the FIFO to the macro write.
        if (fifo_push_i) begin
          assert (request_times.size()>0) else $fatal(1,"Weight FIFO data without a memory request");
          request_cycle=request_times.pop_front();
          stamp.request_cycle=request_cycle;
          stamp.fifo_cycle=cycle;
          fifo_times.push_back(stamp);
        end
        if (macro_write_i) begin
          assert (fifo_times.size()>0) else $fatal(1,"Macro write without a weight FIFO entry");
          stamp=fifo_times.pop_front();
          memory_latency=cycle-stamp.request_cycle;
          fifo_latency=cycle-stamp.fifo_cycle;
          assert (memory_latency>=fifo_latency) else $fatal(1,"Invalid latency timestamps");
          sections++;
          memory_sum+=memory_latency;
          fifo_sum+=fifo_latency;
          if (memory_latency<memory_min) memory_min=memory_latency;
          if (memory_latency>memory_max) memory_max=memory_latency;
          if (fifo_latency<fifo_min) fifo_min=fifo_latency;
          if (fifo_latency>fifo_max) fifo_max=fifo_latency;
          // The first section's original request timestamp survives both
          // queues. Its 128th macro write completes that full weight tile.
          // Keep separate progress for each macro because loading overlaps
          // the other macro's computation.
          if (weight_sections[load_macro_i]==0)
            weight_tile_start[load_macro_i]=stamp.request_cycle;
          weight_sections[load_macro_i]++;
          if (weight_sections[load_macro_i]==128) begin
            add_sample(weight_tile_stats[load_macro_i],cycle-weight_tile_start[load_macro_i]);
            weight_sections[load_macro_i]=0;
          end
        end
        for (int m=0; m<2; m++) begin
          // Observe actual feature-buffer writes, including the prefetched
          // first vector. Gaps between its four sections contribute to time.
          if (feature_load_i[m]) begin
            assert (int'(feature_addr_i[m])==vector_sections[m])
              else $fatal(1,"Input-vector sections out of order on macro %0d",m);
            if (vector_sections[m]==0) vector_start[m]=cycle;
            vector_sections[m]++;
            if (vector_sections[m]==4) begin
              add_sample(vector_stats[m],cycle-vector_start[m]);
              vector_sections[m]=0;
            end
          end
          // A matvec starts when row 0 is actually issued. Keep a queue:
          // the next matvec can begin before the previous one's final result
          // emerges from the pipeline, so one start register is insufficient.
          if (compute_issue_i[m] && compute_addr_i[m]==0) begin
            matvec_stamp.macro_id=1'(m);
            matvec_stamp.start_cycle=cycle;
            matvec_starts.push_back(matvec_stamp);
          end
        end
        // Count actual accumulator updates, not requests or FSM transitions.
        // Every 256 updates completes one 32x128 by 128x8 tile product.
        if (result_pop_i) begin
          results_in_product++;
          // Every 32 accumulated results completes one matvec. Match it to
          // its issued row-0 timestamp rather than estimating pipeline delay.
          if (results_in_product%32==0) begin
            assert (matvec_starts.size()>0) else $fatal(1,"Matvec results without an issue timestamp");
            matvec_stamp=matvec_starts.pop_front();
            assert (matvec_stamp.macro_id==active_macro_i)
              else $fatal(1,"Matvec issue/result macro mismatch");
            add_sample(matvec_stats[active_macro_i],cycle-matvec_stamp.start_cycle);
          end
          if (results_in_product==256) begin
            results_in_product=0;
            products++;
            macro_products[active_macro_i]++;
            if (products<=5)
              $display("[TIMING] %0d tile product(s) complete: %0d cumulative cycles (latest: macro %0d)",
                products,cycle-start_cycle,active_macro_i);
          end
        end
        if (output_tile_accept_i) output_tiles++;
        // Controller completion follows the final output memory writes and the
        // datapath completion. Its HWPE event is registered at this same edge.
        if (job_done_i) begin
          assert (products==expected_products && results_in_product==0 &&
                  output_tiles==expected_outputs && sections==expected_products*128 &&
                  request_times.size()==0 && fifo_times.size()==0 &&
                  matvec_starts.size()==0 && !request_waiting)
            else $fatal(1,"Incomplete timing samples at job completion");
          $display("[TIMING] FULL MATRIX MULTIPLICATION complete: %0d cycles (including output writes)",
            cycle-start_cycle);
          $display("[TIMING] Completed: %0d tile products; macro 0=%0d, macro 1=%0d; output tiles=%0d",
            products,macro_products[0],macro_products[1],output_tiles);
          $display("[TIMING] Weight sections measured: %0d (including repeated tile loads)",sections);
          $display("[TIMING] Memory request -> macro write: min=%0d avg=%0.3f max=%0d cycles",
            memory_min,real'(memory_sum)/real'(sections),memory_max);
          $display("[TIMING] Weight FIFO acceptance -> macro write: min=%0d avg=%0.3f max=%0d cycles",
            fifo_min,real'(fifo_sum)/real'(sections),fifo_max);
          for (int m=0; m<2; m++) begin
            assert (weight_tile_stats[m].samples==macro_products[m] &&
                    vector_stats[m].samples==macro_products[m]*8 &&
                    matvec_stats[m].samples==macro_products[m]*8 &&
                    weight_sections[m]==0 && vector_sections[m]==0)
              else $fatal(1,"Incomplete per-macro timing samples for macro %0d",m);
            print_stats(m,"weight tile (first memory request -> last macro write)",weight_tile_stats[m]);
            print_stats(m,"input vector (first -> fourth feature write)",vector_stats[m]);
            print_stats(m,"matvec (row 0 issued -> 32nd result accumulated)",matvec_stats[m]);
          end
          measuring=0;
        end
      end
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
    .clk_i(clk), .rst_ni(rst_n), .busy_o(busy), .evt_o(evt),
    .periph, .input_tcdm(input_mem), .kernel_tcdm(weight_mem), .output_tcdm(output_mem)
  );
  // +TIMING_ONLY selects one complete job instead of the multi-job regression.
  bit timing_only=$test$plusargs("TIMING_ONLY");
  int timing_stalls=0;
  tb_dimc_timing_monitor i_timing (
    .clk_i(clk), .rst_ni(rst_n), .enable_i(timing_only), .stalls_i(stalls),
    .job_start_i(i_dut.dp_start), .job_done_i(i_dut.i_ctrl.slave_ctrl.done),
    .config_i(i_dut.config_), .memory_req_i(weight_mem.req), .memory_gnt_i(weight_mem.gnt),
    .fifo_push_i(i_dut.i_datapath.wgt_push), .macro_write_i(i_dut.i_datapath.weight_load),
    .load_macro_i(i_dut.i_datapath.load_macro),
    .feature_load_i(~i_dut.i_datapath.fcsn), .feature_addr_i(i_dut.i_datapath.fa),
    .compute_issue_i(i_dut.i_datapath.compe & ~i_dut.i_datapath.rcsn),
    .compute_addr_i(i_dut.i_datapath.ra),
    .result_pop_i(i_dut.i_datapath.result_pop), .active_macro_i(i_dut.i_datapath.active_q),
    .output_tile_accept_i(i_dut.result_valid && i_dut.result_ready)
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
    if (timing_only) begin
      void'($value$plusargs("TIMING_STALLS=%d",timing_stalls));
      assert (timing_stalls==0 || timing_stalls==1)
        else $fatal(1,"TIMING_STALLS must be 0 or 1");
      run_job(4,3,2,1'(timing_stalls));
      $display("[TIMING] Single-job golden-result check PASSED");
      $finish;
    end
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
