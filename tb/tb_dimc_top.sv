// Numbered end-to-end tests for the two-module accelerator.
// Every test sets up a job through the software interface and checks memory.
// +TEST=N runs one numbered test; without it all tests run sequentially.
`timescale 1ns/1ps
module tb_dimc_top;
  import dimc_package::*;
  // Shared simulation storage, loaded from stimulus files and checked below.
  logic [7:0] mem [int unsigned]; // Preserve X values; missing data must fail.
  logic clk=0;
  always #5ns clk=~clk;
  logic rst_n=0, stalls=0, busy;
  logic [1:0] hold_input='0, hold_weight='0, hold_output='0;
  logic [1:0][1:0] evt;
  hwpe_ctrl_intf_periph #(.ID_WIDTH(10)) periph (.clk(clk));
  hci_core_intf #(.DW(256), .IW(1), .EW(0), .EHW(0)) memory [0:1] (.clk(clk));
  dimc_top i_dut (
    .clk_i(clk), .rst_ni(rst_n), .busy_o(busy), .evt_o(evt),
    .periph, .tcdm(memory[0]), .tcdm_2(memory[1])
  );
  // Assigned after reading matrix dimensions; leave aligned guard space.
  int unsigned WBASE, IBASE, OBASE, WBASE_2, IBASE_2, OBASE_2;
  logic [31:0] weight_bytes, input_bytes, output_bytes;
  int response_delay=2;
  int input_count, weight_count, output_count;
  int input_count_2, weight_count_2, output_count_2;
  // Direct behavioral HCI handling: one copy per DIMC port, sharing mem.
  // Keep queued reads so consecutive requests and response backpressure work.
  // These queues are simulation bookkeeping, not accelerator FIFOs.
  int input_counts[2], weight_counts[2], output_counts[2];
  assign input_count=input_counts[0];
  assign weight_count=weight_counts[0];
  assign output_count=output_counts[0];
  assign input_count_2=input_counts[1];
  assign weight_count_2=weight_counts[1];
  assign output_count_2=output_counts[1];
  for (genvar p=0;p<2;p++) begin : memory_handling
    typedef struct packed {logic [255:0] data; logic id; int due;} response_t;
    response_t responses[64];
    int rd=0, wr=0, queued=0;
    int cycle=0;
    logic hold_input_q, hold_weight_q, hold_output_q;
    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin hold_input_q<=0; hold_weight_q<=0; hold_output_q<=0; end
      else begin hold_input_q<=hold_input[p]; hold_weight_q<=hold_weight[p]; hold_output_q<=hold_output[p]; end
    end
    logic is_input, is_weight, is_output, held, accepted, consumed;
    logic [31:0] address;
    logic [255:0] write_data;
    logic [31:0] byte_en;
    logic read_, id_;
    assign is_input = memory[p].add >= (p==0 ? IBASE : IBASE_2) && 64'(memory[p].add)+32 <= 64'((p==0 ? IBASE : IBASE_2))+input_bytes;
    assign is_weight = memory[p].add >= (p==0 ? WBASE : WBASE_2) && 64'(memory[p].add)+32 <= 64'((p==0 ? WBASE : WBASE_2))+weight_bytes;
    assign is_output = memory[p].add >= (p==0 ? OBASE : OBASE_2) && 64'(memory[p].add)+32 <= 64'((p==0 ? OBASE : OBASE_2))+output_bytes;
    assign held = (is_input && hold_input_q) || (is_weight && hold_weight_q) || (is_output && hold_output_q);
    assign memory[p].gnt = rst_n && memory[p].req && !held && (!memory[p].wen || queued<64) &&
                      (!stalls || (cycle+(p+1))%5 != 0);
    assign memory[p].r_valid = rst_n && queued>0 && cycle >= responses[rd].due;
    assign memory[p].r_data = queued>0 ? responses[rd].data : '0;
    assign memory[p].r_id = queued>0 ? responses[rd].id : '0;
    assign memory[p].r_user = '0;
    assign memory[p].r_opc = 0;
    assign memory[p].r_ecc = '0;
    assign memory[p].egnt = '0;
    assign memory[p].r_evalid = '0;
    always @(posedge clk) begin
      if (!rst_n) begin
        rd=0; wr=0; queued=0; cycle=0; input_counts[p]=0; weight_counts[p]=0; output_counts[p]=0;
      end else begin
        accepted=memory[p].req && memory[p].gnt; consumed=memory[p].r_valid && memory[p].r_ready;
        address=memory[p].add; write_data=memory[p].data; byte_en=memory[p].be; read_=memory[p].wen; id_=memory[p].id;
        if (accepted) begin
          assert ((read_ && (is_input || is_weight)) || (!read_ && is_output))
            else $fatal(1,"Shared memory direction or bounds error: %h",address);
          if (is_input) input_counts[p]++;
          if (is_weight) weight_counts[p]++;
          if (is_output) output_counts[p]++;
        end
        #0;
        if (consumed) begin rd=(rd+1)%64; queued--; end
        if (accepted) begin
          if (read_) begin
            assert (queued<64) else $fatal(1,"Read response queue overflow");
            for (int b=0;b<32;b++) responses[wr].data[b*8 +: 8]=mem[address+b];
            responses[wr].id=id_; responses[wr].due=cycle+response_delay;
            wr=(wr+1)%64; queued++;
          end else begin
            assert (&byte_en) else $fatal(1,"Partial output beat");
            for (int b=0;b<32;b++) if (byte_en[b]) mem[address+b]=write_data[b*8 +: 8];
          end
        end
        cycle <= cycle+1;
      end
    end
  end
  logic [7:0] weights[];
  logic [8191:0] input_tiles[];
  logic [31:0] golden[];
  logic [7:0] weights_2[];
  logic [8191:0] input_tiles_2[];
  logic [31:0] golden_2[];
  string stimulus_dir_1="stimuli/double_buffering";
  string stimulus_dir_2="stimuli/double_buffering_module2";
  logic [31:0] status;
  int selected_test=0, test_number=0, passed=0;
  int matrix_k=6, matrix_l=7, matrix_q=5; // Source file tile counts; test 1 uses the full matrices.
  int matrix_precision=8; // Test 1 precision; other tests select their own modes.
  bit tests_passed=0;
  longint unsigned watchdog_cycles=500000;
  string test_name="initialization";

  // Test 1 alone uses this passive observer; both modules share its cycle 0.
  logic test1_timing_done;
  bit test1_verified=0;
  logic [1:0] timing_weight_load, timing_load_macro, timing_active_macro, timing_result_push;
  logic [1:0] timing_input_push;
  logic [1:0][7:0] timing_weight_section;
  logic [1:0][31:0] timing_compute_tile;
  logic [1:0][2:0] timing_compute_vector;
  logic [1:0][1:0] timing_feature_load, timing_compute_issue;
  logic [1:0][1:0][1:0] timing_feature_section;
  logic [1:0][1:0][6:0] timing_compute_row;
  assign timing_weight_load[0] = i_dut.i_module_1.i_datapath.weight_load;
  assign timing_input_push[0] = i_dut.i_module_1.i_datapath.inp_push;
  assign timing_load_macro[0] = i_dut.i_module_1.i_datapath.load_macro;
  assign timing_active_macro[0] = i_dut.i_module_1.i_datapath.active_q;
  assign timing_result_push[0] = i_dut.i_module_1.i_datapath.i_cleopatra.u_dimc_dual.out_push;
  assign timing_weight_section[0] = i_dut.i_module_1.i_datapath.weights_loaded_q;
  assign timing_compute_tile[0] = ((i_dut.i_module_1.i_datapath.k_q*i_dut.i_module_1.i_datapath.q_size_q+i_dut.i_module_1.i_datapath.q_q)*i_dut.i_module_1.i_datapath.l_size_q+i_dut.i_module_1.i_datapath.l_q+1);
  assign timing_compute_vector[0] = i_dut.i_module_1.i_datapath.vector_q;
  assign timing_feature_load[0] = ~i_dut.i_module_1.i_datapath.fcsn;
  assign timing_compute_issue[0] = i_dut.i_module_1.i_datapath.compe & ~i_dut.i_module_1.i_datapath.rcsn;
  assign timing_feature_section[0] = i_dut.i_module_1.i_datapath.fa;
  assign timing_compute_row[0] = i_dut.i_module_1.i_datapath.ra;
  assign timing_weight_load[1] = i_dut.i_module_2.i_datapath.weight_load;
  assign timing_input_push[1] = i_dut.i_module_2.i_datapath.inp_push;
  assign timing_load_macro[1] = i_dut.i_module_2.i_datapath.load_macro;
  assign timing_active_macro[1] = i_dut.i_module_2.i_datapath.active_q;
  assign timing_result_push[1] = i_dut.i_module_2.i_datapath.i_cleopatra.u_dimc_dual.out_push;
  assign timing_weight_section[1] = i_dut.i_module_2.i_datapath.weights_loaded_q;
  assign timing_compute_tile[1] = ((i_dut.i_module_2.i_datapath.k_q*i_dut.i_module_2.i_datapath.q_size_q+i_dut.i_module_2.i_datapath.q_q)*i_dut.i_module_2.i_datapath.l_size_q+i_dut.i_module_2.i_datapath.l_q+1);
  assign timing_compute_vector[1] = i_dut.i_module_2.i_datapath.vector_q;
  assign timing_feature_load[1] = ~i_dut.i_module_2.i_datapath.fcsn;
  assign timing_compute_issue[1] = i_dut.i_module_2.i_datapath.compe & ~i_dut.i_module_2.i_datapath.rcsn;
  assign timing_feature_section[1] = i_dut.i_module_2.i_datapath.fa;
  assign timing_compute_row[1] = i_dut.i_module_2.i_datapath.ra;
  tb_dimc_test1_timing i_test1_timing (
    .clk_i(clk), .rst_ni(rst_n), .enable_i(test_number==1), .verified_i(test1_verified),
    .start_request_i(periph.req && periph.gnt && !periph.wen && periph.add==0),
    .config_i(i_dut.config_), .weight_load_i(timing_weight_load),
    .load_macro_i(timing_load_macro), .active_macro_i(timing_active_macro),
    .result_push_i(timing_result_push), .weight_section_i(timing_weight_section),
    .input_push_i(timing_input_push),
    .compute_tile_i(timing_compute_tile), .compute_vector_i(timing_compute_vector),
    .feature_load_i(timing_feature_load), .compute_issue_i(timing_compute_issue),
    .feature_section_i(timing_feature_section), .compute_row_i(timing_compute_row),
    .output_grant_i({i_dut.i_module_2.output_tcdm.req && i_dut.i_module_2.output_tcdm.gnt, i_dut.i_module_1.output_tcdm.req && i_dut.i_module_1.output_tcdm.gnt}),
    .done_o(test1_timing_done)
  );

  // Test helpers only: report a failed check, drive the bus, prepare memory,
  // and compare output words. Timing is separate and enabled only for test 1.
  task automatic check_condition(input logic condition, input string message_);
    if (condition !== 1'b1)
      $fatal(1,"[DIMC_TOP] Test %0d (%s): FAIL - %s",test_number,test_name,message_);
  endtask

  task automatic begin_test(input int number_, input string name_);
    test_number=number_; test_name=name_;
    $display("[DIMC_TOP] Test %0d: %s",test_number,test_name);
    @(negedge clk);
    rst_n=0; stalls=0; response_delay=2;
    hold_input='0; hold_weight='0; hold_output='0;
    periph.req=0;
    repeat (4) @(negedge clk);
    rst_n=1;
    repeat (8) @(negedge clk);
  endtask

  task automatic pass_test;
    passed++;
    $display("[DIMC_TOP] Test %0d: PASS - %s",test_number,test_name);
  endtask

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
  task automatic configure(input int nk,nl,nq, input int sign_mode=0, bias=0, mode_=3);
    logic [31:0] acquired;
    access(1,'h04,0,acquired);
    check_condition(!acquired[31],"Cannot acquire HWPE context");
    reg_write(DIMC_REG_INPUT_ADDR,IBASE);
    reg_write(DIMC_REG_KERNEL_ADDR,WBASE);
    reg_write(DIMC_REG_OUTPUT_ADDR,OBASE);
    reg_write(DIMC_REG_INPUT_ADDR_2,IBASE_2);
    reg_write(DIMC_REG_KERNEL_ADDR_2,WBASE_2);
    reg_write(DIMC_REG_OUTPUT_ADDR_2,OBASE_2);
    reg_write(DIMC_REG_WEIGHT_ROWS,nk*32);
    // Inner registers are packed BYTES at every precision, not element counts.
    reg_write(DIMC_REG_WEIGHT_COLS,nl*128);
    reg_write(DIMC_REG_INPUT_ROWS,nl*128);
    reg_write(DIMC_REG_INPUT_COLS,nq*8);
    reg_write(DIMC_REG_FORMAT,mode_ | (sign_mode<<2));
    reg_write(DIMC_REG_BIAS,bias);
    reg_write(DIMC_REG_COMPUTE_MASK,0);
    for (int i=0;i<8;i++) reg_write(DIMC_REG_WRITE_MASK+i,'1);
  endtask

  // Weights/results stay row-major. Copy packed input tiles directly from
  // the tiled-input file order into memory, first file byte at lowest address.
  // Source tile stride is matrix_l; selected jobs can use fewer inner tiles.
  task automatic fill_memory(input int nk,nl,nq);
    weight_bytes=nk*32*nl*128;
    input_bytes=nl*128*nq*8;
    output_bytes=nk*32*nq*8*4;
    for (int r=0;r<nk*32;r++)
      for (int c=0;c<nl*128;c++) mem[WBASE+r*nl*128+c]=weights[r*(matrix_l*128)+c];
    for (int q=0;q<nq;q++)
      for (int l=0;l<nl;l++)
        for (int b=0;b<1024;b++)
          mem[IBASE+(q*nl+l)*1024+b]=input_tiles[q*matrix_l+l][8191-b*8 -:8];
    for (int r=0;r<nk*32;r++)
      for (int c=0;c<nl*128;c++) mem[WBASE_2+r*nl*128+c]=weights_2[r*(matrix_l*128)+c];
    for (int q=0;q<nq;q++)
      for (int l=0;l<nl;l++)
        for (int b=0;b<1024;b++)
          mem[IBASE_2+(q*nl+l)*1024+b]=input_tiles_2[q*matrix_l+l][8191-b*8 -:8];
    for (int b=-32;b<int'(output_bytes)+32;b++) begin
      mem[OBASE+b]='ha5;
      mem[OBASE_2+b]='ha5;
    end
  endtask

  task automatic start_job;
    wr('h00,0);
    wait(busy);
  endtask

  task automatic wait_completion;
    do @(negedge clk); while (!evt[0][0]);
    @(negedge clk);
  endtask

  // Use only the public software status bits, not internal RTL hierarchy.
  task automatic wait_module_done(input int module_number);
    logic [31:0] status;
    access(1,'h18,0,status);
    while (!status[3+module_number]) access(1,'h18,0,status);
  endtask

  task automatic wait_abort;
    while (busy) begin
      @(negedge clk);
      check_condition(!evt[0][0],"Aborted job generated a completion event");
    end
  endtask

  task automatic check_idle;
    logic [31:0] status;
    check_condition(!busy,"Controller still busy after completion");
    access(1,'h18,0,status);
    check_condition(status=='h30,"Both modules must report completed");
  endtask

  // Golden files contain compact row-major results for the selected test.
  // Python performs the arithmetic; this TB only compares each output word.
  task automatic check_results(input int nk,nq, input string golden_file);
    logic [31:0] got_1,got_2;
    int index_;
    // Clear old expectations so a missing/short file cannot reuse prior data.
    for (int i=0;i<nk*32*nq*8;i++) begin
      golden[i]='x; golden_2[i]='x;
    end
    $readmemh({stimulus_dir_1,"/",golden_file},golden,0,nk*32*nq*8-1);
    $readmemh({stimulus_dir_2,"/",golden_file},golden_2,0,nk*32*nq*8-1);
    for (int r=0;r<nk*32;r++) begin
      for (int c=0;c<nq*8;c++) begin
        index_=r*nq*8+c;
        for (int b=0;b<4;b++) begin
          got_1[b*8 +: 8]=mem[OBASE+4*index_+b];
          got_2[b*8 +: 8]=mem[OBASE_2+4*index_+b];
        end
        check_condition(got_1===golden[index_],
          $sformatf("Module 1 result [%0d,%0d]: got %h, golden %h",r,c,got_1,golden[index_]));
        check_condition(got_2===golden_2[index_],
          $sformatf("Module 2 result [%0d,%0d]: got %h, golden %h",r,c,got_2,golden_2[index_]));
      end
    end
    for (int b=1;b<=32;b++) begin
      check_condition(mem[OBASE-b]=='ha5 && mem[OBASE+output_bytes+b-1]=='ha5,
                      "Module 1 wrote outside its output region");
      check_condition(mem[OBASE_2-b]=='ha5 && mem[OBASE_2+output_bytes+b-1]=='ha5,
                      "Module 2 wrote outside its output region");
    end
  endtask

  task automatic test_1;
    begin_test(1,"Full matrix multiplication - both modules expected to match golden results");
    fill_memory(matrix_k,matrix_l,matrix_q); // Load both modules' complete matrices from files.
    configure(matrix_k,matrix_l,matrix_q,0,0,$clog2(matrix_precision)); // Unsigned selected precision, zero bias.
    start_job();
    wait_completion();
    check_idle();
    if (matrix_precision==8)
      check_results(matrix_k,matrix_q,"double_buffering_golden_matmul_output.txt");
    else
      check_results(matrix_k,matrix_q,$sformatf("double_buffering_golden_matmul_output_%0dbit.txt",matrix_precision));
    check_condition(test1_timing_done,"Test 1 timing did not reach both final output writes");
    test1_verified=1;
    @(negedge clk); // Allow the observer to publish the verified report.
    pass_test();
  endtask
  task automatic test_2;
    begin_test(2,"Memory stalls");
    fill_memory(4,3,2); // Load both modules: weights 128x384, inputs 384x16.
    configure(4,3,2,0,0); // Shared K/L/Q=4/3/2; unsigned 8-bit, bias=0 once per output.
    stalls=1; // Periodically withhold grants on both shared memory ports.
    start_job();
    wait_completion();
    check_idle();
    check_results(4,2,"double_buffering_golden_matmul_output.txt"); // Compare both 128x16 output matrices with their goldens.
    pass_test();
  endtask
  task automatic test_3;
    begin_test(3,"Module 1 input channel stalled - module 2 continues");
    fill_memory(1,1,1); // Load both modules: weights 32x128, inputs 128x8.
    configure(1,1,1); // Shared K/L/Q=1/1/1; unsigned 8-bit, bias=0 once per output.
    hold_input[0]=1; // Block module 1 input memory grants.
    start_job();
    wait_module_done(2); // Wait for module 2 to finish independently.
    access(1,'h18,0,status); // Read busy, error and per-module completion bits.
    check_condition(busy && !evt[0][0],"Overall completion occurred while one module was blocked");
    check_condition(status[5] && !status[4],"Only the unblocked module should be complete");
    check_condition(output_count==0,"Blocked module wrote output");
    @(negedge clk);
    hold_input[0]=0; // Resume module 1 input memory grants.
    wait_completion();
    check_idle();
    check_results(1,1,"top_small_golden.txt"); // Compare both 32x8 output matrices with their goldens.
    pass_test();
  endtask
  task automatic test_4;
    begin_test(4,"Module 1 weight channel stalled - module 2 continues");
    fill_memory(1,1,1); // Load both modules: weights 32x128, inputs 128x8.
    configure(1,1,1); // Shared K/L/Q=1/1/1; unsigned 8-bit, bias=0 once per output.
    hold_weight[0]=1; // Block module 1 weight memory grants.
    start_job();
    wait_module_done(2); // Wait for module 2 to finish independently.
    access(1,'h18,0,status); // Read busy, error and per-module completion bits.
    check_condition(busy && !evt[0][0],"Overall completion occurred while one module was blocked");
    check_condition(status[5] && !status[4],"Only the unblocked module should be complete");
    check_condition(output_count==0,"Blocked module wrote output");
    @(negedge clk);
    hold_weight[0]=0; // Resume module 1 weight memory grants.
    wait_completion();
    check_idle();
    check_results(1,1,"top_small_golden.txt"); // Compare both 32x8 output matrices with their goldens.
    pass_test();
  endtask
  task automatic test_5;
    begin_test(5,"Module 1 output channel stalled - module 2 continues");
    fill_memory(1,1,1); // Load both modules: weights 32x128, inputs 128x8.
    configure(1,1,1); // Shared K/L/Q=1/1/1; unsigned 8-bit, bias=0 once per output.
    hold_output[0]=1; // Block module 1 output memory grants.
    start_job();
    wait_module_done(2); // Wait for module 2 to finish independently.
    access(1,'h18,0,status); // Read busy, error and per-module completion bits.
    check_condition(busy && !evt[0][0],"Overall completion occurred while one module was blocked");
    check_condition(status[5] && !status[4],"Only the unblocked module should be complete");
    check_condition(output_count==0,"Blocked module wrote output");
    @(negedge clk);
    hold_output[0]=0; // Resume module 1 output memory grants.
    wait_completion();
    check_idle();
    check_results(1,1,"top_small_golden.txt"); // Compare both 32x8 output matrices with their goldens.
    pass_test();
  endtask

  task automatic test_6;
    begin_test(6,"Restart after abort");
    fill_memory(4,3,2); // Load both modules: weights 128x384, inputs 384x16.
    configure(4,3,2); // Shared K/L/Q=4/3/2; unsigned 8-bit, bias=0 once per output.
    response_delay=30; // Return memory read responses after 30 cycles.
    start_job();
    wait(i_dut.i_module_1.input_tcdm.req && i_dut.i_module_1.input_tcdm.gnt);
    wr('h14,0); // Request shared abort/soft clear.
    wait_abort();
    repeat (8) @(negedge clk);
    // No reset here: the replacement job must work after the abort itself.
    response_delay=2; // Return memory read responses after 2 cycles.
    fill_memory(1,1,1); // Load both modules: weights 32x128, inputs 128x8.
    configure(1,1,1); // Shared K/L/Q=1/1/1; unsigned 8-bit, bias=0 once per output.
    start_job();
    wait_completion();
    check_idle();
    check_results(1,1,"top_small_golden.txt"); // Compare both 32x8 output matrices with their goldens.
    pass_test();
  endtask
  task automatic test_7;
    begin_test(7,"Queued jobs retain their own configuration");
    fill_memory(1,2,1); // Load both modules: weights 32x256, inputs 256x8.
    configure(1,2,1,0,1); // Shared K/L/Q=1/2/1; unsigned 8-bit, bias=1 once per output.
    start_job();
    // Queue another context while the first job is still running.
    configure(1,2,1,3,-9); // Shared K/L/Q=1/2/1; signed 8-bit, bias=-9 once per output.
    wr('h00,0); // Commit and trigger the queued job.
    wait_completion();
    check_results(1,1,"top_queued_first_golden.txt"); // Compare both 32x8 output matrices with their goldens.
    wait_completion();
    check_idle();
    check_results(1,1,"top_queued_second_golden.txt"); // Compare both 32x8 output matrices with their goldens.
    pass_test();
  endtask
  task automatic test_8;
    for (int sign_mode=1;sign_mode<=2;sign_mode++) begin
      begin_test(8,"Mixed signed operands and one bias across three inner tiles");
      fill_memory(1,3,1);
      configure(1,3,1,sign_mode,sign_mode==1 ? -17 : 23);
      stalls=1; response_delay=13;
      start_job(); wait_completion(); check_idle();
      check_results(1,1,sign_mode==1 ? "top_mixed_01_golden.txt" : "top_mixed_10_golden.txt");
    end
    pass_test();
  endtask
  task automatic test_9;
    for (int mode_=0;mode_<3;mode_++) begin
      begin_test(9,$sformatf("Unsigned %0d-bit packed operands, both modules",1<<mode_));
      fill_memory(2,3,2);
      // Set both sign bits deliberately: only 8-bit mode may interpret them.
      configure(2,3,2,3,-7,mode_);
      stalls=1; response_delay=13;
      start_job(); wait_completion(); check_idle();
      check_results(2,2,$sformatf("top_precision_%0dbit_golden.txt",1<<mode_));
    end
    pass_test();
  endtask
  task automatic test_10;
    logic [255:0] mask=256'h0123456789abcdef13579bdf2468ace0fedcba98765432100f1e2d3c4b5a6979;
    int compute_masks[6]='{0,1,5,257,1023,1024};
    for (int mode_=0;mode_<4;mode_++) begin
      for (int i=0;i<6;i++) begin
        begin_test(10,$sformatf("Unsigned %0d-bit masking, compute mask=%0d",1<<mode_,compute_masks[i]));
        // Reset on every subcase keeps disabled weight bits initially zero.
        fill_memory(1,3,1); configure(1,3,1,0,-11,mode_);
        reg_write(DIMC_REG_COMPUTE_MASK,compute_masks[i]);
        for (int word_=0;word_<8;word_++)
          reg_write(DIMC_REG_WRITE_MASK+word_,mask[word_*32 +:32]);
        stalls=1; response_delay=13;
        start_job(); wait_completion(); check_idle();
        check_results(1,1,$sformatf("top_mask_%0dbit_%0d_golden.txt",1<<mode_,compute_masks[i]));
      end
    end
    pass_test();
  endtask
  initial begin
    longint unsigned source_weights, source_inputs, source_outputs, next_base;
    periph.req=0; periph.add=0; periph.wen=1; periph.data=0;
    periph.be='1; periph.id=1;
    void'($value$plusargs("TEST=%d",selected_test));
    check_condition(selected_test>=0 && selected_test<=10,
                    "TEST must be 0 (all) or 1..10");
    void'($value$plusargs("MATRIX_K=%d",matrix_k));
    void'($value$plusargs("MATRIX_L=%d",matrix_l));
    void'($value$plusargs("MATRIX_Q=%d",matrix_q));
    void'($value$plusargs("PRECISION=%d",matrix_precision));
    check_condition(matrix_precision==1 || matrix_precision==2 || matrix_precision==4 || matrix_precision==8,
                    "PRECISION must be 1, 2, 4, or 8");
    check_condition(matrix_k>=1 && matrix_l>=1 && matrix_q>=1,
                    "MATRIX_K, MATRIX_L and MATRIX_Q must be positive");
    // Check in wide arithmetic before allocation or 32-bit address conversion.
    source_weights=64'(matrix_k)*32*64'(matrix_l)*128;
    source_inputs=64'(matrix_l)*128*64'(matrix_q)*8;
    source_outputs=64'(matrix_k)*32*64'(matrix_q)*8;
    check_condition(source_weights<=64'h7fffffff && source_inputs<=64'h7fffffff &&
                    source_outputs<=64'h1fffffff,
                    "Matrices exceed supported array indexing or byte-count range");
    weights=new[int'(source_weights)]; weights_2=new[int'(source_weights)];
    input_tiles=new[int'(source_inputs/1024)]; input_tiles_2=new[int'(source_inputs/1024)];
    golden=new[int'(source_outputs)]; golden_2=new[int'(source_outputs)];
    next_base='h1000;
    WBASE=32'(next_base);
    next_base=(next_base+source_weights+63)&~64'd31;
    check_condition(next_base<64'h100000000,"Weight region exceeds 32-bit address space");
    IBASE=32'(next_base);
    next_base=(next_base+source_inputs+63)&~64'd31;
    check_condition(next_base<64'h100000000,"Input region exceeds 32-bit address space");
    OBASE=32'(next_base);
    next_base=(next_base+source_outputs*4+63)&~64'd31;
    check_condition(next_base<64'h100000000,"Output region exceeds 32-bit address space");
    WBASE_2=32'(next_base);
    next_base=(next_base+source_weights+63)&~64'd31;
    check_condition(next_base<64'h100000000,"Module 2 weight region exceeds 32-bit address space");
    IBASE_2=32'(next_base);
    next_base=(next_base+source_inputs+63)&~64'd31;
    check_condition(next_base<64'h100000000,"Module 2 input region exceeds 32-bit address space");
    OBASE_2=32'(next_base);
    next_base=next_base+source_outputs*4+32;
    check_condition(next_base<=64'h100000000,"Matrices exceed 32-bit memory address space");
    watchdog_cycles=500000+64'(matrix_k)*64'(matrix_l)*64'(matrix_q)*1000;
    check_condition(selected_test==1 || (matrix_k==4 && matrix_l==3 && matrix_q==2),
                    "Custom matrix dimensions require TEST=1; other tests use the default source sizes");
    void'($value$plusargs("STIM_DIR_1=%s",stimulus_dir_1));
    void'($value$plusargs("STIM_DIR_2=%s",stimulus_dir_2));
    $display("[DIMC_TOP] Module 1 stimulus: %s",stimulus_dir_1);
    $display("[DIMC_TOP] Module 2 stimulus: %s",stimulus_dir_2);
    $readmemh({stimulus_dir_1,"/double_buffering_kernel_stim.txt"},weights,0,matrix_k*32*matrix_l*128-1);
    $readmemh({stimulus_dir_1,"/double_buffering_tiled_inputs.txt"},input_tiles,0,matrix_l*matrix_q-1);
    $readmemh({stimulus_dir_2,"/double_buffering_kernel_stim.txt"},weights_2,0,matrix_k*32*matrix_l*128-1);
    $readmemh({stimulus_dir_2,"/double_buffering_tiled_inputs.txt"},input_tiles_2,0,matrix_l*matrix_q-1);
    if (selected_test==0 || selected_test==1) test_1();
    if (selected_test==0 || selected_test==2) test_2();
    if (selected_test==0 || selected_test==3) test_3();
    if (selected_test==0 || selected_test==4) test_4();
    if (selected_test==0 || selected_test==5) test_5();
    if (selected_test==0 || selected_test==6) test_6();
    if (selected_test==0 || selected_test==7) test_7();
    if (selected_test==0 || selected_test==8) test_8();
    if (selected_test==0 || selected_test==9) test_9();
    if (selected_test==0 || selected_test==10) test_10();
    $display("[DIMC_TOP] RESULTS: %0d PASSED, 0 FAILED",passed);
    $display("[DIMC_TOP] ALL SELECTED TESTS PASSED");
    tests_passed=1;
    $finish;
  end

  initial begin
    #1ns; // Dimension-dependent budget is assigned during initialization.
    #(watchdog_cycles*10ns);
    $fatal(1,"[DIMC_TOP] Test %0d (%s): FAIL - timeout",test_number,test_name);
  end

endmodule