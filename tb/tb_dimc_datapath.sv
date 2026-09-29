// Standalone double-buffered datapath regression. Uses Test 1's matrices,
// exercises runtime dimensions, source stalls, result backpressure and restart.
//
// WHAT THIS FILE DOES
// A testbench is a simulation environment, not hardware added to the chip.
// Here it substitutes for the unfinished control module, streamer and result
// receiver. i_dut (Device Under Test) is the real dimc_datapath RTL instance.
// The testbench supplies commands/data and checks what the RTL produces.
// It does NOT drive macro addresses, select macros, or schedule accumulation;
// those operations are performed by the FSM inside dimc_datapath.
//
// JOB vs TASK
// A job is one complete matrix multiplication, from start to done. It can
// require many input/weight tile pairs and produce many 32x8 output tiles.
// A SystemVerilog task is a named, reusable procedure, like a function that
// can also wait for clock edges and therefore take simulation time to finish.
// Calling run_job executes one test job; send_inputs/send_weights are helper
// tasks that supply its data. A task is not itself a hardware processing unit.
// 'automatic' gives each call its own local variables and argument storage.
//
// K/nk = number of 32-row weight groups; L/nl = number of 128-element inner
// groups; Q/nq = number of 8-column input groups. Thus one job computes:
//   (nk*32 by nl*128) x (nl*128 by nq*8) -> (nk*32 by nq*8).
// For each output tile [k][q], nl tile products must be accumulated.
//
// TILING vs DELIVERY
// The Python stimulus generator creates full matrices and tiled files before
// simulation (make sim-datapath invokes it). This testbench reads those tiles,
// then sends their 256-bit sections in [k][q][l] order, including repeats.
// These send loops model the delivery order required of the future streamer.
`timescale 1ns/1ps
module tb_dimc_datapath;
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
  // Smaller jobs select subsets of it; the RTL itself is not limited to these
  // test sizes. Array sizes and strides here describe the stimulus files.
  // 12 weight tiles: each 32 rows * 1024 bits = 32768 bits, indexed k*3+l.
  // 6 input tiles: each 8 columns * 1024 bits = 8192 bits, indexed q*3+l.
  // The literal 3 is the dataset's L, even when a test job uses nl=1 or nl=2.
  logic [32767:0] weights [0:11];
  logic [8191:0] inputs [0:5];
  // Untiled row-major matrices are kept ONLY for the independent checker:
  // weights = 128x384, inputs = 384x16, golden full output = 128x16.
  // These simulation arrays are not storage inside dimc_datapath.
  logic [7:0] raw_weights [0:49151];
  logic [7:0] raw_inputs [0:6143];
  logic [31:0] golden [0:2047];
  int overlap_cycles = 0;
  // Passive monitor: hierarchical references observe internal control pins
  // but never drive them. Count evidence that double buffering really overlaps
  // computation on one macro with weight loading on the other.
  // Also ensure two macros never consume the shared FIFO simultaneously.
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
  // Each [k][q][l] step sends input tile [l][q]; k does not affect which input
  // tile is selected, so the same tiles are deliberately resent for each k.
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

  // Model the independent weight source. Each weight tile [k][l] is resent
  // for each q because a different output-column tile needs the same weights.
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
  // 32x8 tile at a time, not one 32-bit stream word. There are nk*nq tiles;
  // nl does not appear in these receive loops because the RTL has already
  // accumulated all nl contributions before asserting result_valid.
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
            // Independent reference: compute one full dot product directly
            // from the original untiled matrices, not the DUT's accumulator.
            // Full row = k*32+r; full column = q*8+c. The source arrays keep
            // strides 384 and 16 even when the selected job is smaller.
            // 32' casts widen byte values for multiplication/accumulation.
            for (int n = 0; n < nl*128; n++)
              expected += 32'(raw_weights[(k*32+r)*384+n]) *
                          32'(raw_inputs[n*16+q*8+c]);
            assert (result[r][c] === expected)
              else $fatal(1, "Tile [%0d,%0d] element [%0d,%0d]: got %h expected %h",
                          k, q, r, c, result[r][c], expected);
            // The golden file sums all three inner tiles. It also applies to
            // smaller K/Q subsets, but not to a job that selects fewer L tiles.
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
        // After checking stability for 11 cycles, accept the whole tile at
        // the next rising edge. This releases the DUT to clear accumulators.
        result_ready = 1;
        @(negedge clk);
        result_ready = 0;
      end
    end
    // Completion must follow acceptance of the LAST tile, with ready low and
    // no pending result. A further cycle checks that done does not stay high.
    wait (done);
    @(negedge clk);
    assert (!ready && !result_valid) else $fatal(1, "Job failed to complete");
    @(negedge clk);
    assert (!done) else $fatal(1, "done must be a pulse");
  endtask

  // Launch and verify one complete matrix multiplication. This task models
  // control-module setup, then runs both stream sources and the receiver.
  // It returns only after all three finish. Later calls change dimensions
  // on the same hardware instance without resetting between successful jobs.
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
    // fork/join launches these three SIMULATION procedures concurrently.
    // join waits for all of them. Sequential calls would deadlock: the sender
    // can be backpressured while the DUT waits for an output to be accepted.
    fork
      send_inputs(nk, nl, nq, gap);
      send_weights(nk, nl, nq, gap);
      receive_results(nk, nl, nq);
    join
    $display("[DATAPATH] PASS K=%0d L=%0d Q=%0d source_gap=%0d", nk, nl, nq, gap);
  endtask

  // Main test sequence: an initial block runs once at simulation start.
  // strb='1 marks all 32 bytes valid; partial beats/tiles are not tested here.
  initial begin
    input_stream.valid = 0;
    input_stream.data = 0;
    input_stream.strb = '1;
    kernel_stream.valid = 0;
    kernel_stream.data = 0;
    kernel_stream.strb = '1;
    // Read pre-generated hexadecimal files into simulation arrays. $readmemh
    // performs file I/O here; it is not a runtime memory interface in the DUT.
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
    // Supply one tile pair, let computation begin, and assert clear before
    // completion. The next job must not inherit FIFO data or partial sums.
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
    $finish;
  end
  // Independent watchdog runs concurrently with the main initial block.
  // A stuck handshake/FSM must fail the test instead of simulating forever.
  initial begin
    #2ms;
    $fatal(1, "Datapath timeout");
  end
endmodule
