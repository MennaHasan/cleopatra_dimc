`timescale 1ns/1ps
module tb_dimc_datapath;
  bit tests_passed = 0;
  // 10 ns clock period. Drive stimulus on falling edges so it is stable when
  // the DUT samples on rising edges; this avoids testbench/DUT sampling races.
  logic clk = 0;
  always #5ns clk = ~clk;
  logic rst_n = 0, clear = 0, start = 0;
  logic [31:0] weight_rows, weight_cols, input_rows, input_cols;
  logic ready, done, result_valid, result_ready = 0;
  logic [31:0] result [0:31][0:7];
  // Each stream carries data, byte strobes, valid (sender has data), and ready
  // (receiver can accept it). A rising edge with valid && ready transfers one
  // BEAT = 256 bits = 32 eight-bit matrix elements, not a whole tile.
  hwpe_stream_intf_stream #(.DATA_WIDTH(256)) input_stream (.clk(clk));
  hwpe_stream_intf_stream #(.DATA_WIDTH(256)) kernel_stream (.clk(clk));
  // Tests use unsigned 8-bit elements, zero bias, all write bits enabled, and
  // no compute masking. All computation occurs within this instantiated RTL.
  dimc_datapath i_dut (
    .clk_i(clk), .rst_ni(rst_n), .clear_i(clear), .start_i(start),
    .weight_rows_i(weight_rows), .weight_cols_i(weight_cols),
    .input_rows_i(input_rows), .input_cols_i(input_cols),
    .mode_i(2'b11), .sign_8b_i(2'b00), .bias_i(32'd0),
    .write_mask_i({256{1'b1}}), .compute_mask_i(10'd0),
    .input_i(input_stream), .kernel_i(kernel_stream),
    .ready_o(ready), .done_o(done),
    .result_o(result), .result_valid_o(result_valid), .result_ready_i(result_ready)
  );

  // Fixed SOURCE DATASET dimensions: K=4, L=3, Q=2.
  logic [32767:0] weights [0:11];
  logic [8191:0] inputs [0:5];
  // Untiled row-major matrices are kept ONLY for the independent checker:
  // weights = 128x384, inputs = 384x16, golden full output = 128x16.
  // These simulation arrays are not storage inside dimc_datapath.
  logic [7:0] raw_weights [0:49151];
  logic [7:0] raw_inputs [0:6143];
  logic [31:0] golden [0:2047];
  int overlap_cycles = 0;
  
  always @(posedge clk) begin
    if (rst_n && !clear &&
        ((i_dut.compe[0] && !i_dut.wcsn[1]) ||
         (i_dut.compe[1] && !i_dut.wcsn[0]))) overlap_cycles++;
    if (rst_n && !clear) begin
      assert (!(i_dut.fcsn == 2'b00)) else $fatal(1, "Shared input FIFO contention");
      assert (!(i_dut.wcsn == 2'b00)) else $fatal(1, "Shared weight FIFO contention");
    end
  end

  // Model the streamer's input-data source for an entire job.
  // Each [k][q][l] step sends input tile [l][q];
  // gap inserts deterministic pauses to check that the RTL tolerates stalls.
  task automatic send_inputs(input int nk, nl, nq, gap);
    for (int k = 0; k < nk; k++)
      for (int q = 0; q < nq; q++)
        for (int l = 0; l < nl; l++)
          for (int beat = 0; beat < 32; beat++) begin
            // Pause every fifth beat. The previous beat has already completed.
            repeat ((beat % 5 == 0) ? gap : 0) @(negedge clk);
            // '-: 256' selects 256 bits downwards from the given bit index.
            // Take the packed tile MSB first: column 0's four sections, then
            // column 1's four sections, and so on through column 7.
            input_stream.data = inputs[q*3+l][8191-beat*256 -: 256];
            input_stream.valid = 1;
            // Keep this SAME beat valid until a rising edge sees ready high.
            // Waiting for ready alone is insufficient; acceptance needs an edge.
            do @(posedge clk); while (!input_stream.ready);
            @(negedge clk);
            input_stream.valid = 0;
          end
  endtask

  // Model the independent weight source. 
  // Independent source tasks allow weights and features to arrive concurrently.
  task automatic send_weights(input int nk, nl, nq, gap);
    for (int k = 0; k < nk; k++)
      for (int q = 0; q < nq; q++)
        for (int l = 0; l < nl; l++)
          for (int beat = 0; beat < 128; beat++) begin
            repeat ((beat % 7 == 0) ? gap : 0) @(negedge clk);
            // MSB-first packed order: row 0 sections 0..3, row 1 sections
            // 0..3, ... row 31. Four beats form one complete weight row.
            kernel_stream.data = weights[k*3+l][32767-beat*256 -: 256];
            kernel_stream.valid = 1;
            do @(posedge clk); while (!kernel_stream.ready);
            @(negedge clk);
            kernel_stream.valid = 0;
          end
  endtask

  // Model the result receiver AND check correctness. The output is one entire
  // 32x8 tile at a time
  task automatic receive_results(input int nk, nl, nq);
    logic [31:0] expected, saved [0:31][0:7];
    for (int k = 0; k < nk; k++) begin
      for (int q = 0; q < nq; q++) begin
        do @(negedge clk); while (!result_valid);
        assert (i_dut.k_q == k && i_dut.q_q == q && ready && !done)
          else $fatal(1, "Wrong output coordinates or status");
        for (int r = 0; r < 32; r++) begin
          for (int c = 0; c < 8; c++) begin
            expected = 0;
            // compute one full dot product directly
            for (int n = 0; n < nl*128; n++)
              expected += 32'(raw_weights[(k*32+r)*384+n]) *
                          32'(raw_inputs[n*16+q*8+c]);
            assert (result[r][c] === expected)
              else $fatal(1, "Tile [%0d,%0d] element [%0d,%0d]: got %h expected %h",
                          k, q, r, c, result[r][c], expected);
            if (nl == 3)
              assert (result[r][c] === golden[(k*32+r)*16+q*8+c])
                else $fatal(1, "Test 1 golden mismatch");
            saved[r][c] = result[r][c];
          end
        end
        // Consumer stalls must preserve both the entire tile and its coordinates.
        repeat (11) begin
          @(negedge clk);
          assert (result_valid && !done && ready && i_dut.k_q == k && i_dut.q_q == q)
            else $fatal(1, "Result/status changed under backpressure");
          for (int r = 0; r < 32; r++)
            for (int c = 0; c < 8; c++)
              assert (result[r][c] === saved[r][c]) else $fatal(1, "Result changed while stalled");
        end
        result_ready = 1;
        @(negedge clk);
        result_ready = 0;
      end
    end
    // A further cycle checks that done does not stay high.
    wait (done);
    @(negedge clk);
    assert (!ready && !result_valid) else $fatal(1, "Job failed to complete");
    @(negedge clk);
    assert (!done) else $fatal(1, "done must be a pulse");
  endtask

  // Launch and verify one complete matrix multiplication.
  task automatic run_job(input int nk, nl, nq, gap);
    @(negedge clk);
    weight_rows = nk*32;
    weight_cols = nl*128;
    input_rows = nl*128;
    input_cols = nq*8;
    start = 1;
    @(negedge clk);
    start = 0;
    assert (ready) else $fatal(1, "Setup did not become ready");
    // External dimensions need not remain stable after the command is accepted.
    weight_rows = 0;
    weight_cols = 0;
    input_rows = 0;
    input_cols = 0;
    // fork/join launches these three  procedures concurrently.
    fork
      send_inputs(nk, nl, nq, gap);
      send_weights(nk, nl, nq, gap);
      receive_results(nk, nl, nq);
    join
    $display("[DATAPATH] PASS K=%0d L=%0d Q=%0d source_gap=%0d", nk, nl, nq, gap);
  endtask

  initial begin
    input_stream.valid = 0;
    input_stream.data = 0;
    input_stream.strb = '1;
    kernel_stream.valid = 0;
    kernel_stream.data = 0;
    kernel_stream.strb = '1;
    // Read pre-generated hexadecimal files into simulation arrays. $readmemh
    $readmemh("stimuli/double_buffering/double_buffering_tiled_weights.txt", weights);
    $readmemh("stimuli/double_buffering/double_buffering_tiled_inputs.txt", inputs);
    $readmemh("stimuli/double_buffering/double_buffering_kernel_stim.txt", raw_weights);
    $readmemh("stimuli/double_buffering/double_buffering_feature_stim.txt", raw_inputs);
    $readmemh("stimuli/double_buffering/double_buffering_golden_matmul_output.txt", golden);
    repeat (3) @(negedge clk);
    rst_n = 1;
    // Full job: 24 tile products yield 8 output tiles (2048 output values).
    run_job(4, 3, 2, 0);
    run_job(1, 1, 1, 0); // final computation on macro 0
    run_job(1, 2, 1, 19); // final computation on macro 1, stalled sources
    run_job(1, 3, 1, 3); // odd number of tile products
    run_job(2, 1, 2, 1); // output/clear boundary after every product
    // Abort during an active pipeline, then restart without external reset.
    // Supply one tile pair, let computation begin, and assert clear before completion. 
    @(negedge clk);
    weight_rows = 32; weight_cols = 128; input_rows = 128; input_cols = 8;
    start = 1;
    @(negedge clk);
    start = 0;
    fork
      send_inputs(1, 1, 1, 0);
      send_weights(1, 1, 1, 0);
    join
    wait (i_dut.compe != 0);
    repeat (3) @(negedge clk);
    clear = 1;
    @(negedge clk);
    assert (!ready && !result_valid && !input_stream.ready && !kernel_stream.ready)
      else $fatal(1, "Clear did not abort the job");
    clear = 0;
    run_job(1, 1, 1, 2);
    assert (overlap_cycles > 0) else $fatal(1, "No concurrent compute/load observed");
    $display("[DATAPATH] ALL TESTS PASSED; %0d overlapping compute/load cycles", overlap_cycles);
    tests_passed = 1;
    $finish;
  end
  initial begin
    #2ms;
    $fatal(1, "Datapath timeout");
  end
endmodule
