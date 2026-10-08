// Numbered end-to-end tests for the two-module accelerator.
// Every test sets up a job through the software interface and checks memory.
// +TEST=N runs one numbered test; without it all tests run sequentially.
`timescale 1ns/1ps
module tb_dimc_top;
  import dimc_package::*;
  import tb_dimc_memory::*;
  logic clk=0;
  always #5ns clk=~clk;
  logic rst_n=0, stalls=0, busy;
  logic [1:0] hold_input='0, hold_weight='0, hold_output='0;
  logic [1:0][1:0] evt;
  hwpe_ctrl_intf_periph #(.ID_WIDTH(10)) periph (.clk(clk));
  hci_core_intf #(.DW(64), .IW(1), .EW(0), .EHW(0)) input_mem (.clk(clk));
  hci_core_intf #(.DW(256), .IW(1), .EW(0), .EHW(0)) weight_mem (.clk(clk));
  hci_core_intf #(.DW(256), .IW(1), .EW(0), .EHW(0)) output_mem (.clk(clk));
  hci_core_intf #(.DW(64), .IW(1), .EW(0), .EHW(0)) input_mem_2 (.clk(clk));
  hci_core_intf #(.DW(256), .IW(1), .EW(0), .EHW(0)) weight_mem_2 (.clk(clk));
  hci_core_intf #(.DW(256), .IW(1), .EW(0), .EHW(0)) output_mem_2 (.clk(clk));
  dimc_top i_dut (
    .clk_i(clk), .rst_ni(rst_n), .busy_o(busy), .evt_o(evt),
    .periph, .input_tcdm(input_mem), .kernel_tcdm(weight_mem), .output_tcdm(output_mem),
    .input_tcdm_2(input_mem_2), .kernel_tcdm_2(weight_mem_2), .output_tcdm_2(output_mem_2)
  );
  localparam int WBASE='h1000, IBASE='h11000, OBASE='h14000;
  localparam int WBASE_2='h18000, IBASE_2='h28000, OBASE_2='h2b000;
  logic [31:0] weight_bytes, input_bytes, output_bytes;
  int response_delay=2;
  int input_count, weight_count, output_count;
  int input_count_2, weight_count_2, output_count_2;
  tb_dimc_memory_port #(.DW(64), .SALT(1)) i_input_memory (
    .clk_i(clk), .rst_ni(rst_n), .stalls_i(stalls), .response_delay_i(response_delay), .hold_i(hold_input[0]), .port(input_mem),
    .region_base_i(32'(IBASE)), .region_bytes_i(input_bytes), .transfers_o(input_count)
  );
  tb_dimc_memory_port #(.DW(256), .SALT(2)) i_weight_memory (
    .clk_i(clk), .rst_ni(rst_n), .stalls_i(stalls), .response_delay_i(response_delay), .hold_i(hold_weight[0]), .port(weight_mem),
    .region_base_i(32'(WBASE)), .region_bytes_i(weight_bytes), .transfers_o(weight_count)
  );
  tb_dimc_memory_port #(.DW(256), .SALT(3), .WRITE_PORT(1)) i_output_memory (
    .clk_i(clk), .rst_ni(rst_n), .stalls_i(stalls), .response_delay_i(response_delay), .hold_i(hold_output[0]), .port(output_mem),
    .region_base_i(32'(OBASE)), .region_bytes_i(output_bytes), .transfers_o(output_count)
  );
  tb_dimc_memory_port #(.DW(64), .SALT(4)) i_input_memory_2 (
    .clk_i(clk), .rst_ni(rst_n), .stalls_i(stalls), .response_delay_i(response_delay), .hold_i(hold_input[1]), .port(input_mem_2),
    .region_base_i(32'(IBASE_2)), .region_bytes_i(input_bytes), .transfers_o(input_count_2)
  );
  tb_dimc_memory_port #(.DW(256), .SALT(5)) i_weight_memory_2 (
    .clk_i(clk), .rst_ni(rst_n), .stalls_i(stalls), .response_delay_i(response_delay), .hold_i(hold_weight[1]), .port(weight_mem_2),
    .region_base_i(32'(WBASE_2)), .region_bytes_i(weight_bytes), .transfers_o(weight_count_2)
  );
  tb_dimc_memory_port #(.DW(256), .SALT(6), .WRITE_PORT(1)) i_output_memory_2 (
    .clk_i(clk), .rst_ni(rst_n), .stalls_i(stalls), .response_delay_i(response_delay), .hold_i(hold_output[1]), .port(output_mem_2),
    .region_base_i(32'(OBASE_2)), .region_bytes_i(output_bytes), .transfers_o(output_count_2)
  );
  logic [7:0] weights [0:65535], inputs [0:8191];
  logic [31:0] golden [0:2047];
  logic [7:0] weights_2 [0:65535], inputs_2 [0:8191];
  logic [31:0] golden_2 [0:2047];
  string stimulus_dir_1="stimuli/double_buffering";
  string stimulus_dir_2="stimuli/double_buffering_module2";
  logic [31:0] status;
  int selected_test=0, test_number=0, passed=0;
  int matrix_k=4, matrix_l=3, matrix_q=2; // Source file tile counts; test 1 uses the full matrices.
  bit tests_passed=0;
  string test_name="initialization";

  // Test 1 alone uses this passive observer; both modules share its cycle 0.
  logic test1_timing_done;
  logic [1:0] timing_weight_load, timing_load_macro, timing_active_macro, timing_result_pop;
  logic [1:0][7:0] timing_weight_section;
  logic [1:0][31:0] timing_compute_tile;
  logic [1:0][2:0] timing_compute_vector;
  logic [1:0][1:0] timing_feature_load, timing_compute_issue;
  logic [1:0][1:0][1:0] timing_feature_section;
  logic [1:0][1:0][6:0] timing_compute_row;
  assign timing_weight_load[0] = i_dut.i_module_1.i_datapath.weight_load;
  assign timing_load_macro[0] = i_dut.i_module_1.i_datapath.load_macro;
  assign timing_active_macro[0] = i_dut.i_module_1.i_datapath.active_q;
  assign timing_result_pop[0] = i_dut.i_module_1.i_datapath.result_pop;
  assign timing_weight_section[0] = i_dut.i_module_1.i_datapath.weights_loaded_q;
  assign timing_compute_tile[0] = ((i_dut.i_module_1.i_datapath.k_q*i_dut.i_module_1.i_datapath.q_size_q+i_dut.i_module_1.i_datapath.q_q)*i_dut.i_module_1.i_datapath.l_size_q+i_dut.i_module_1.i_datapath.l_q+1);
  assign timing_compute_vector[0] = i_dut.i_module_1.i_datapath.vector_q;
  assign timing_feature_load[0] = ~i_dut.i_module_1.i_datapath.fcsn;
  assign timing_compute_issue[0] = i_dut.i_module_1.i_datapath.compe & ~i_dut.i_module_1.i_datapath.rcsn;
  assign timing_feature_section[0] = i_dut.i_module_1.i_datapath.fa;
  assign timing_compute_row[0] = i_dut.i_module_1.i_datapath.ra;
  assign timing_weight_load[1] = i_dut.i_module_2.i_datapath.weight_load;
  assign timing_load_macro[1] = i_dut.i_module_2.i_datapath.load_macro;
  assign timing_active_macro[1] = i_dut.i_module_2.i_datapath.active_q;
  assign timing_result_pop[1] = i_dut.i_module_2.i_datapath.result_pop;
  assign timing_weight_section[1] = i_dut.i_module_2.i_datapath.weights_loaded_q;
  assign timing_compute_tile[1] = ((i_dut.i_module_2.i_datapath.k_q*i_dut.i_module_2.i_datapath.q_size_q+i_dut.i_module_2.i_datapath.q_q)*i_dut.i_module_2.i_datapath.l_size_q+i_dut.i_module_2.i_datapath.l_q+1);
  assign timing_compute_vector[1] = i_dut.i_module_2.i_datapath.vector_q;
  assign timing_feature_load[1] = ~i_dut.i_module_2.i_datapath.fcsn;
  assign timing_compute_issue[1] = i_dut.i_module_2.i_datapath.compe & ~i_dut.i_module_2.i_datapath.rcsn;
  assign timing_feature_section[1] = i_dut.i_module_2.i_datapath.fa;
  assign timing_compute_row[1] = i_dut.i_module_2.i_datapath.ra;
  tb_dimc_test1_timing i_test1_timing (
    .clk_i(clk), .rst_ni(rst_n), .enable_i(test_number==1),
    .start_request_i(periph.req && periph.gnt && !periph.wen && periph.add==0),
    .config_i(i_dut.config_), .weight_load_i(timing_weight_load),
    .load_macro_i(timing_load_macro), .active_macro_i(timing_active_macro),
    .result_pop_i(timing_result_pop), .weight_section_i(timing_weight_section),
    .compute_tile_i(timing_compute_tile), .compute_vector_i(timing_compute_vector),
    .feature_load_i(timing_feature_load), .compute_issue_i(timing_compute_issue),
    .feature_section_i(timing_feature_section), .compute_row_i(timing_compute_row),
    .output_grant_i({output_mem_2.req && output_mem_2.gnt, output_mem.req && output_mem.gnt}),
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
  task automatic configure(input int nk,nl,nq, input int sign_mode=0, bias=0);
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
    reg_write(DIMC_REG_WEIGHT_COLS,nl*128);
    reg_write(DIMC_REG_INPUT_ROWS,nl*128);
    reg_write(DIMC_REG_INPUT_COLS,nq*8);
    reg_write(DIMC_REG_FORMAT,3 | (sign_mode<<2));
    reg_write(DIMC_REG_BIAS,bias);
    reg_write(DIMC_REG_COMPUTE_MASK,0);
    for (int i=0;i<8;i++) reg_write(DIMC_REG_WRITE_MASK+i,'1);
  endtask

  // Store the selected matrices contiguously, row-major, in simulated memory.
  // File strides follow the source matrix dimensions; memory strides use this job's sizes.
  task automatic fill_memory(input int nk,nl,nq);
    weight_bytes=nk*32*nl*128;
    input_bytes=nl*128*nq*8;
    output_bytes=nk*32*nq*8*4;
    for (int r=0;r<nk*32;r++)
      for (int c=0;c<nl*128;c++) mem[WBASE+r*nl*128+c]=weights[r*(matrix_l*128)+c];
    for (int r=0;r<nl*128;r++)
      for (int c=0;c<nq*8;c++) mem[IBASE+r*nq*8+c]=inputs[r*(matrix_q*8)+c];
    for (int r=0;r<nk*32;r++)
      for (int c=0;c<nl*128;c++) mem[WBASE_2+r*nl*128+c]=weights_2[r*(matrix_l*128)+c];
    for (int r=0;r<nl*128;r++)
      for (int c=0;c<nq*8;c++) mem[IBASE_2+r*nq*8+c]=inputs_2[r*(matrix_q*8)+c];
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
        check_condition(!$isunknown(golden[index_]) && got_1===golden[index_],
          $sformatf("Module 1 result [%0d,%0d]: got %h, golden %h",r,c,got_1,golden[index_]));
        check_condition(!$isunknown(golden_2[index_]) && got_2===golden_2[index_],
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
    configure(matrix_k,matrix_l,matrix_q,0,0); // Shared dimensions; unsigned 8-bit, zero bias.
    start_job();
    wait_completion();
    check_idle();
    check_results(matrix_k,matrix_q,"double_buffering_golden_matmul_output.txt"); // Compare every output element in both modules.
    check_condition(test1_timing_done,"Test 1 timing did not reach both final output writes");
    pass_test();
  endtask

  task automatic test_2;
    begin_test(2,"Different matrix dimensions");
    fill_memory(2,1,2); // Load both modules: weights 64x128, inputs 128x16.
    configure(2,1,2,0,0); // Shared K/L/Q=2/1/2; unsigned 8-bit, bias=0 per inner tile.
    start_job();
    wait_completion();
    check_idle();
    check_results(2,2,"top_dimensions_golden.txt"); // Compare both 64x16 output matrices with their goldens.
    pass_test();
  endtask

  task automatic test_3;
    begin_test(3,"Memory stalls");
    fill_memory(4,3,2); // Load both modules: weights 128x384, inputs 384x16.
    configure(4,3,2,0,0); // Shared K/L/Q=4/3/2; unsigned 8-bit, bias=0 per inner tile.
    stalls=1; // Periodically withhold grants on all six memory channels.
    start_job();
    wait_completion();
    check_idle();
    check_results(4,2,"double_buffering_golden_matmul_output.txt"); // Compare both 128x16 output matrices with their goldens.
    pass_test();
  endtask

  task automatic test_4;
    begin_test(4,"Signed arithmetic");
    fill_memory(1,2,1); // Load both modules: weights 32x256, inputs 256x8.
    configure(1,2,1,3,0); // Shared K/L/Q=1/2/1; signed 8-bit, bias=0 per inner tile.
    start_job();
    wait_completion();
    check_idle();
    check_results(1,1,"top_signed_golden.txt"); // Compare both 32x8 output matrices with their goldens.
    pass_test();
  endtask

  task automatic test_5;
    begin_test(5,"Bias");
    fill_memory(1,2,1); // Load both modules: weights 32x256, inputs 256x8.
    configure(1,2,1,0,-7); // Shared K/L/Q=1/2/1; unsigned 8-bit, bias=-7 per inner tile.
    start_job();
    wait_completion();
    check_idle();
    check_results(1,1,"top_bias_golden.txt"); // Compare both 32x8 output matrices with their goldens.
    pass_test();
  endtask

  task automatic test_6;
    begin_test(6,"Module 1 input channel stalled - module 2 continues");
    fill_memory(1,1,1); // Load both modules: weights 32x128, inputs 128x8.
    configure(1,1,1); // Shared K/L/Q=1/1/1; unsigned 8-bit, bias=0 per inner tile.
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

  task automatic test_7;
    begin_test(7,"Module 1 weight channel stalled - module 2 continues");
    fill_memory(1,1,1); // Load both modules: weights 32x128, inputs 128x8.
    configure(1,1,1); // Shared K/L/Q=1/1/1; unsigned 8-bit, bias=0 per inner tile.
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

  task automatic test_8;
    begin_test(8,"Module 1 output channel stalled - module 2 continues");
    fill_memory(1,1,1); // Load both modules: weights 32x128, inputs 128x8.
    configure(1,1,1); // Shared K/L/Q=1/1/1; unsigned 8-bit, bias=0 per inner tile.
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

  task automatic test_9;
    begin_test(9,"Module 2 input channel stalled - module 1 continues");
    fill_memory(1,1,1); // Load both modules: weights 32x128, inputs 128x8.
    configure(1,1,1); // Shared K/L/Q=1/1/1; unsigned 8-bit, bias=0 per inner tile.
    hold_input[1]=1; // Block module 2 input memory grants.
    start_job();
    wait_module_done(1); // Wait for module 1 to finish independently.
    access(1,'h18,0,status); // Read busy, error and per-module completion bits.
    check_condition(busy && !evt[0][0],"Overall completion occurred while one module was blocked");
    check_condition(status[4] && !status[5],"Only the unblocked module should be complete");
    check_condition(output_count_2==0,"Blocked module wrote output");
    @(negedge clk);
    hold_input[1]=0; // Resume module 2 input memory grants.
    wait_completion();
    check_idle();
    check_results(1,1,"top_small_golden.txt"); // Compare both 32x8 output matrices with their goldens.
    pass_test();
  endtask

  task automatic test_10;
    begin_test(10,"Module 2 weight channel stalled - module 1 continues");
    fill_memory(1,1,1); // Load both modules: weights 32x128, inputs 128x8.
    configure(1,1,1); // Shared K/L/Q=1/1/1; unsigned 8-bit, bias=0 per inner tile.
    hold_weight[1]=1; // Block module 2 weight memory grants.
    start_job();
    wait_module_done(1); // Wait for module 1 to finish independently.
    access(1,'h18,0,status); // Read busy, error and per-module completion bits.
    check_condition(busy && !evt[0][0],"Overall completion occurred while one module was blocked");
    check_condition(status[4] && !status[5],"Only the unblocked module should be complete");
    check_condition(output_count_2==0,"Blocked module wrote output");
    @(negedge clk);
    hold_weight[1]=0; // Resume module 2 weight memory grants.
    wait_completion();
    check_idle();
    check_results(1,1,"top_small_golden.txt"); // Compare both 32x8 output matrices with their goldens.
    pass_test();
  endtask

  task automatic test_11;
    begin_test(11,"Module 2 output channel stalled - module 1 continues");
    fill_memory(1,1,1); // Load both modules: weights 32x128, inputs 128x8.
    configure(1,1,1); // Shared K/L/Q=1/1/1; unsigned 8-bit, bias=0 per inner tile.
    hold_output[1]=1; // Block module 2 output memory grants.
    start_job();
    wait_module_done(1); // Wait for module 1 to finish independently.
    access(1,'h18,0,status); // Read busy, error and per-module completion bits.
    check_condition(busy && !evt[0][0],"Overall completion occurred while one module was blocked");
    check_condition(status[4] && !status[5],"Only the unblocked module should be complete");
    check_condition(output_count_2==0,"Blocked module wrote output");
    @(negedge clk);
    hold_output[1]=0; // Resume module 2 output memory grants.
    wait_completion();
    check_idle();
    check_results(1,1,"top_small_golden.txt"); // Compare both 32x8 output matrices with their goldens.
    pass_test();
  endtask

  task automatic test_12;
    begin_test(12,"Abort drains outstanding reads");
    fill_memory(4,3,2); // Load both modules: weights 128x384, inputs 384x16.
    configure(4,3,2); // Shared K/L/Q=4/3/2; unsigned 8-bit, bias=0 per inner tile.
    response_delay=30; // Return memory read responses after 30 cycles.
    start_job();
    wait(input_mem.req && input_mem.gnt);
    wr('h14,0); // Request shared abort/soft clear.
    repeat (5) @(negedge clk);
    check_condition(busy,"Abort did not wait for outstanding read responses");
    wait_abort();
    repeat (8) @(negedge clk);
    access(1,'h18,0,status); // Read busy, error and per-module completion bits.
    check_condition(status==0,"Abort left stale status");
    check_condition(output_count==0 && output_count_2==0,"Read abort wrote output");
    pass_test();
  endtask

  task automatic test_13;
    begin_test(13,"Abort drains module 1 stalled output burst");
    fill_memory(1,1,1); // Load both modules: weights 32x128, inputs 128x8.
    configure(1,1,1); // Shared K/L/Q=1/1/1; unsigned 8-bit, bias=0 per inner tile.
    hold_output[0]=1; // Block module 1 output memory grants.
    start_job();
    wait_module_done(2); // Wait for module 2 to finish independently.
    wait(output_mem.req);
    wr('h14,0); // Request shared abort/soft clear.
    repeat (10) @(negedge clk);
    check_condition(busy,"Abort cleared before the stalled output burst drained");
    hold_output[0]=0; // Resume module 1 output memory grants.
    wait_abort();
    repeat (8) @(negedge clk);
    access(1,'h18,0,status); // Read busy, error and per-module completion bits.
    check_condition(status==0,"Abort left stale completion status");
    check_condition(output_count==32 && output_count_2==32,"Output bursts were not fully drained");
    check_results(1,1,"top_small_golden.txt"); // Compare both 32x8 output matrices with their goldens.
    pass_test();
  endtask

  task automatic test_14;
    begin_test(14,"Abort drains module 2 stalled output burst");
    fill_memory(1,1,1); // Load both modules: weights 32x128, inputs 128x8.
    configure(1,1,1); // Shared K/L/Q=1/1/1; unsigned 8-bit, bias=0 per inner tile.
    hold_output[1]=1; // Block module 2 output memory grants.
    start_job();
    wait_module_done(1); // Wait for module 1 to finish independently.
    wait(output_mem_2.req);
    wr('h14,0); // Request shared abort/soft clear.
    repeat (10) @(negedge clk);
    check_condition(busy,"Abort cleared before the stalled output burst drained");
    hold_output[1]=0; // Resume module 2 output memory grants.
    wait_abort();
    repeat (8) @(negedge clk);
    access(1,'h18,0,status); // Read busy, error and per-module completion bits.
    check_condition(status==0,"Abort left stale completion status");
    check_condition(output_count==32 && output_count_2==32,"Output bursts were not fully drained");
    check_results(1,1,"top_small_golden.txt"); // Compare both 32x8 output matrices with their goldens.
    pass_test();
  endtask

  task automatic test_15;
    begin_test(15,"Restart after abort");
    fill_memory(4,3,2); // Load both modules: weights 128x384, inputs 384x16.
    configure(4,3,2); // Shared K/L/Q=4/3/2; unsigned 8-bit, bias=0 per inner tile.
    response_delay=30; // Return memory read responses after 30 cycles.
    start_job();
    wait(input_mem.req && input_mem.gnt);
    wr('h14,0); // Request shared abort/soft clear.
    wait_abort();
    repeat (8) @(negedge clk);
    // No reset here: the replacement job must work after the abort itself.
    response_delay=2; // Return memory read responses after 2 cycles.
    fill_memory(1,1,1); // Load both modules: weights 32x128, inputs 128x8.
    configure(1,1,1); // Shared K/L/Q=1/1/1; unsigned 8-bit, bias=0 per inner tile.
    start_job();
    wait_completion();
    check_idle();
    check_results(1,1,"top_small_golden.txt"); // Compare both 32x8 output matrices with their goldens.
    pass_test();
  endtask

  task automatic test_16;
    begin_test(16,"Queued jobs retain their own configuration");
    fill_memory(1,2,1); // Load both modules: weights 32x256, inputs 256x8.
    configure(1,2,1,0,1); // Shared K/L/Q=1/2/1; unsigned 8-bit, bias=1 per inner tile.
    start_job();
    // Queue another context while the first job is still running.
    configure(1,2,1,3,-9); // Shared K/L/Q=1/2/1; signed 8-bit, bias=-9 per inner tile.
    wr('h00,0); // Commit and trigger the queued job.
    wait_completion();
    check_results(1,1,"top_queued_first_golden.txt"); // Compare both 32x8 output matrices with their goldens.
    wait_completion();
    check_idle();
    check_results(1,1,"top_queued_second_golden.txt"); // Compare both 32x8 output matrices with their goldens.
    pass_test();
  endtask

  task automatic test_17;
    begin_test(17,"Reject incompatible matrix dimensions");
    fill_memory(1,1,1); // Load both modules: weights 32x128, inputs 128x8.
    configure(1,1,1); // Shared K/L/Q=1/1/1; unsigned 8-bit, bias=0 per inner tile.
    reg_write(DIMC_REG_INPUT_ROWS,256); // Input rows 256 differ from weight columns 128: invalid.
    start_job();
    wait_completion();
    access(1,'h18,0,status); // Read busy, error and per-module completion bits.
    check_condition(!busy && status==2,"Invalid job did not report configuration error");
    check_condition(input_count==0 && weight_count==0 && output_count==0 &&
                    input_count_2==0 && weight_count_2==0 && output_count_2==0,
                    "Rejected job issued memory transfers");
    pass_test();
  endtask

  task automatic test_18;
    begin_test(18,"Reject module 1 unaligned address");
    fill_memory(1,1,1); // Load both modules: weights 32x128, inputs 128x8.
    configure(1,1,1); // Shared K/L/Q=1/1/1; unsigned 8-bit, bias=0 per inner tile.
    reg_write(DIMC_REG_OUTPUT_ADDR,OBASE+1); // Misalign module 1 output base by one byte.
    start_job();
    wait_completion();
    access(1,'h18,0,status); // Read busy, error and per-module completion bits.
    check_condition(!busy && status==2,"Invalid job did not report configuration error");
    check_condition(input_count==0 && weight_count==0 && output_count==0 &&
                    input_count_2==0 && weight_count_2==0 && output_count_2==0,
                    "Rejected job issued memory transfers");
    pass_test();
  endtask

  task automatic test_19;
    begin_test(19,"Reject module 2 unaligned address");
    fill_memory(1,1,1); // Load both modules: weights 32x128, inputs 128x8.
    configure(1,1,1); // Shared K/L/Q=1/1/1; unsigned 8-bit, bias=0 per inner tile.
    reg_write(DIMC_REG_OUTPUT_ADDR_2,OBASE_2+1); // Misalign module 2 output base by one byte.
    start_job();
    wait_completion();
    access(1,'h18,0,status); // Read busy, error and per-module completion bits.
    check_condition(!busy && status==2,"Invalid job did not report configuration error");
    check_condition(input_count==0 && weight_count==0 && output_count==0 &&
                    input_count_2==0 && weight_count_2==0 && output_count_2==0,
                    "Rejected job issued memory transfers");
    pass_test();
  endtask

  task automatic test_20;
    begin_test(20,"Reject module 1 address overflow");
    fill_memory(1,1,1); // Load both modules: weights 32x128, inputs 128x8.
    configure(1,1,1); // Shared K/L/Q=1/1/1; unsigned 8-bit, bias=0 per inner tile.
    reg_write(DIMC_REG_KERNEL_ADDR,32'hffffffe0); // Module 1 weight region exceeds the 32-bit address space.
    start_job();
    wait_completion();
    access(1,'h18,0,status); // Read busy, error and per-module completion bits.
    check_condition(!busy && status==2,"Invalid job did not report configuration error");
    check_condition(input_count==0 && weight_count==0 && output_count==0 &&
                    input_count_2==0 && weight_count_2==0 && output_count_2==0,
                    "Rejected job issued memory transfers");
    pass_test();
  endtask

  task automatic test_21;
    begin_test(21,"Reject module 2 address overflow");
    fill_memory(1,1,1); // Load both modules: weights 32x128, inputs 128x8.
    configure(1,1,1); // Shared K/L/Q=1/1/1; unsigned 8-bit, bias=0 per inner tile.
    reg_write(DIMC_REG_KERNEL_ADDR_2,32'hffffffe0); // Module 2 weight region exceeds the 32-bit address space.
    start_job();
    wait_completion();
    access(1,'h18,0,status); // Read busy, error and per-module completion bits.
    check_condition(!busy && status==2,"Invalid job did not report configuration error");
    check_condition(input_count==0 && weight_count==0 && output_count==0 &&
                    input_count_2==0 && weight_count_2==0 && output_count_2==0,
                    "Rejected job issued memory transfers");
    pass_test();
  endtask

  task automatic test_22;
    begin_test(22,"Reject unsupported compute mode");
    fill_memory(1,1,1); // Load both modules: weights 32x128, inputs 128x8.
    configure(1,1,1); // Shared K/L/Q=1/1/1; unsigned 8-bit, bias=0 per inner tile.
    reg_write(DIMC_REG_FORMAT,0); // Select unsupported mode 00 instead of 8-bit mode 11.
    start_job();
    wait_completion();
    access(1,'h18,0,status); // Read busy, error and per-module completion bits.
    check_condition(!busy && status==2,"Invalid job did not report configuration error");
    check_condition(input_count==0 && weight_count==0 && output_count==0 &&
                    input_count_2==0 && weight_count_2==0 && output_count_2==0,
                    "Rejected job issued memory transfers");
    pass_test();
  endtask

  initial begin
    periph.req=0; periph.add=0; periph.wen=1; periph.data=0;
    periph.be='1; periph.id=1;
    void'($value$plusargs("TEST=%d",selected_test));
    check_condition(selected_test>=0 && selected_test<=22,"TEST must be 0 (all) or 1..22");
    void'($value$plusargs("MATRIX_K=%d",matrix_k));
    void'($value$plusargs("MATRIX_L=%d",matrix_l));
    void'($value$plusargs("MATRIX_Q=%d",matrix_q));
    check_condition(matrix_k>=1 && matrix_k<=4 && matrix_l>=1 && matrix_l<=4 &&
                    matrix_q>=1 && matrix_q<=2,"Source matrices exceed supported TB storage (K=1..4, L=1..4, Q=1..2)");
    check_condition(selected_test==1 || (matrix_k==4 && matrix_l==3 && matrix_q==2),
                    "Custom matrix dimensions require TEST=1; other tests use the default source sizes");
    void'($value$plusargs("STIM_DIR_1=%s",stimulus_dir_1));
    void'($value$plusargs("STIM_DIR_2=%s",stimulus_dir_2));
    $display("[DIMC_TOP] Module 1 stimulus: %s",stimulus_dir_1);
    $display("[DIMC_TOP] Module 2 stimulus: %s",stimulus_dir_2);
    $readmemh({stimulus_dir_1,"/double_buffering_kernel_stim.txt"},weights,0,matrix_k*32*matrix_l*128-1);
    $readmemh({stimulus_dir_1,"/double_buffering_feature_stim.txt"},inputs,0,matrix_l*128*matrix_q*8-1);
    $readmemh({stimulus_dir_2,"/double_buffering_kernel_stim.txt"},weights_2,0,matrix_k*32*matrix_l*128-1);
    $readmemh({stimulus_dir_2,"/double_buffering_feature_stim.txt"},inputs_2,0,matrix_l*128*matrix_q*8-1);
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
    if (selected_test==0 || selected_test==11) test_11();
    if (selected_test==0 || selected_test==12) test_12();
    if (selected_test==0 || selected_test==13) test_13();
    if (selected_test==0 || selected_test==14) test_14();
    if (selected_test==0 || selected_test==15) test_15();
    if (selected_test==0 || selected_test==16) test_16();
    if (selected_test==0 || selected_test==17) test_17();
    if (selected_test==0 || selected_test==18) test_18();
    if (selected_test==0 || selected_test==19) test_19();
    if (selected_test==0 || selected_test==20) test_20();
    if (selected_test==0 || selected_test==21) test_21();
    if (selected_test==0 || selected_test==22) test_22();
    $display("[DIMC_TOP] RESULTS: %0d PASSED, 0 FAILED",passed);
    $display("[DIMC_TOP] ALL SELECTED TESTS PASSED");
    tests_passed=1;
    $finish;
  end

  initial begin
    #5ms;
    $fatal(1,"[DIMC_TOP] Test %0d (%s): FAIL - timeout",test_number,test_name);
  end
endmodule
