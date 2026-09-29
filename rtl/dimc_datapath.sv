/*
 * dimc_datapath.sv
 *
 * A JOB is one complete matrix multiplication: Result = Weights x Inputs.
 * One start command launches a job, which can require many tile products.
 * The hardware size stays fixed while the matrix dimensions change per job.
 *
 * With 8-bit elements:
 *   Weights: (K*32) rows x (L*128) columns
 *   Inputs:  (L*128) rows x (Q*8) columns
 *   Result:  (K*32) rows x (Q*8) columns
 * K, L and Q are tile COUNTS; k, l and q are zero-based tile INDICES.
 * For one output tile [k][q], the hardware computes:
 *   result_tile[k][q] = sum over l of weight_tile[k][l] x input_tile[l][q].
 * Each tile product contributes 256 values to the same 256 accumulators.
 * Only after all L contributions is that output tile ready to send.
 * A job therefore computes K*Q*L tile products and sends K*Q output tiles.
 *
 * This module sequences Cleopatra; Cleopatra contains the two DIMC macros,
 * shared FIFOs, accumulator selector, and 256 accumulators. The streamer
 * must supply already ordered tiles. This module does not read external
 * memory, tile full matrices, or retain the full input/output matrices.
 *
 * Double buffering means computing on one macro while loading the next
 * tile into the other. The FSM and counters below implement this in RTL.
 * Testbench tasks only supply/receive data; they do not execute this FSM.
 */
module dimc_datapath
  import dimc_package::*;
#(
  parameter int unsigned SECTION_WIDTH  = 256, // width of one DIMC memory/compute section
  parameter int unsigned INP_FIFO_DEPTH = 32,
  parameter int unsigned WGT_FIFO_DEPTH = 128,
  parameter int unsigned OUT_FIFO_DEPTH = 64
)
(
  input  logic                 clk_i,
  input  logic                 rst_ni,
  input  logic                 clear_i,

  // Start a job and latch its matrix dimensions (in elements) and configuration.
  // Pulse start_i for one clock when idle (ready_o is low). These inputs are sampled
  // once, so the controller may change them after the command is accepted.
  // clear_i aborts a job; it is different from clearing one completed tile.
  input  logic                 start_i,
  input  logic [31:0]          weight_rows_i,
  input  logic [31:0]          weight_cols_i,
  input  logic [31:0]          input_rows_i,
  input  logic [31:0]          input_cols_i,
  input  logic [1:0]           mode_i,
  input  logic [1:0]           sign_8b_i,
  input  logic [31:0]          bias_i,
  input  logic [SECTION_WIDTH-1:0] write_mask_i,
  input  logic [9:0]           compute_mask_i,


  /*
  A beat is one data transfer, accepted on a rising clock edge when both valid and ready are high.
  Here, each beat carries 256 bits (SECTION_WIDTH), so:
  - One 1024-bit row/vector takes 4 beats.
  - One weight tile takes 128 beats.
  - One input tile takes 32 beats.
  If valid or ready is low, no transfer happens that cycle.
  */

  // input feature stream from dimc_streamer (one SECTION_WIDTH-wide section per beat)
  hwpe_stream_intf_stream.sink   input_i,
  // kernel (weight) stream from dimc_streamer (one SECTION_WIDTH-wide section per beat)
  hwpe_stream_intf_stream.sink   kernel_i,

  // Job status; stream ready signals control individual input transfers.
  // ready_o means setup has completed, NOT that every stream can accept a
  // beat right now. Use input_i.ready/kernel_i.ready for individual beats.
  // ready_o stays high until completion, including result backpressure.
  output logic                 ready_o, // setup complete, ready to receive tiles
  output logic                 done_o,  // pulse after the final result tile is accepted

  // Hold each result tile until accepted; emit tiles in [k][q] order, q first.
  // result_o[row][col] maps to full result [k*32+row][q*8+col].
  // One output handshake accepts ALL 256 values. A receiver that reads values
  // individually must keep result_ready_i low until it has captured the tile.
  // Data is meaningful while result_valid_o is high.
  output logic [31:0]          result_o [0:31][0:7],
  output logic                 result_valid_o,
  input  logic                 result_ready_i
);
  localparam int NUM_SECTIONS = 4;
  localparam int WEIGHT_BEATS = 128;
  localparam int INPUT_BEATS = 32;

  typedef enum logic [2:0] {IDLE, LOAD_FIRST, RUN, PRESENT, CLEAR_TILE,
                           ADVANCE} state_t;
  typedef enum logic [1:0] {ROWS, FEATURES, DRAIN} compute_state_t;
  state_t state_q;
  compute_state_t compute_state_q;
  // The suffix _q denotes registered values, updated at clock edges.
  // Sizes/configuration stay fixed for a job; k_q/l_q/q_q track computation,
  // while the parallel loader may already be preparing the following tile.
  logic [31:0] k_size_q, l_size_q, q_size_q;
  logic [31:0] k_q, l_q, q_q;
  logic [1:0] mode_q, sign_q;
  logic [31:0] bias_q;
  logic [SECTION_WIDTH-1:0] mask_q;
  logic [9:0] compute_mask_q;
  logic active_q, load_macro;
  logic has_next, load_enable, next_loaded, phase_complete, valid_config;
  logic core_rst_n, acc_clear, result_pop;
  logic inp_full, inp_empty, wgt_full, wgt_empty, inp_push, wgt_push;
  // Received counts track stream -> FIFO transfers; loaded counts track
  // FIFO -> macro transfers. Receiving a beat does not mean it is loaded yet.
  // These counts describe the tile being LOADED (the next tile during RUN).
  logic [7:0] weights_received_q, weights_loaded_q;
  logic [5:0] inputs_received_q;
  // first_sections_q counts 0..4 sections of the loading macro's vector 0.
  // vector_q (0..7), section_q (0..3), and row_q (0..31) describe the ACTIVE
  // macro's computation. results_q counts 0..256 results actually accumulated,
  // rather than compute commands issued: the pipeline takes time to finish.
  logic [2:0] first_sections_q, vector_q;
  logic [1:0] section_q;
  logic [4:0] row_q;
  logic [8:0] results_q;
  logic weight_load, first_load, feature_load;
  // COMPE is active high. FCSN/RCSN/WCSN are active low (0 requests work).

  logic [1:0] compe, fcsn, rcsn, wcsn;
  logic [1:0][1:0] fa;
  logic [1:0][6:0] ra, wa;
  logic [31:0] acc [0:255];

  // clear_i aborts the whole job, including queued data and pipeline results.
  assign core_rst_n = rst_ni & ~clear_i;
  assign ready_o = (state_q != IDLE) & core_rst_n;
  assign result_valid_o = (state_q == PRESENT) & core_rst_n;
  // These generate loops create fixed wiring, not clock-by-clock loops.
  // Cleopatra produces rows 0..31 for column 0, then rows for column 1, etc.
  // Hence accumulator index = column*32 + row. No extra result buffer is
  // allocated: PRESENT holds the accumulators unchanged until acceptance.
  for (genvar r = 0; r < 32; r++) begin : gen_result_rows
    for (genvar c = 0; c < 8; c++) begin : gen_result_cols
      assign result_o[r][c] = acc[c*32+r];
    end
  end

  // Low-bit checks implement divisibility by powers of two (32, 128, 8).
  // There is no partial-tile padding for now. 
  // Invalid starts remain in IDLE.
  assign valid_config = weight_rows_i != 0 && weight_cols_i != 0 &&
                        input_cols_i != 0 && weight_cols_i == input_rows_i &&
                        weight_rows_i[4:0] == 0 && weight_cols_i[6:0] == 0 &&
                        input_cols_i[2:0] == 0 && mode_i == 2'b11;
  // Another tile product exists unless ALL three indices are at their ends.
  // On the final product, do not request data for a nonexistent next tile.
  assign has_next = (l_q != l_size_q-1) || (q_q != q_size_q-1) ||
                    (k_q != k_size_q-1);
  assign load_enable = (state_q == LOAD_FIRST) || (state_q == RUN && has_next);
  assign load_macro = (state_q == LOAD_FIRST) ? 1'b0 : ~active_q;
  // Backpressure: deassert ready when the FIFO is full or the expected tile
  // has already arrived. The sender must retain valid/data until accepted.
  // Both streams are independent and can stall for different durations.
  assign input_i.ready = core_rst_n && load_enable &&
                         inputs_received_q < INPUT_BEATS && !inp_full;
  assign kernel_i.ready = core_rst_n && load_enable &&
                          weights_received_q < WEIGHT_BEATS && !wgt_full;
  assign inp_push = input_i.valid && input_i.ready;
  assign wgt_push = kernel_i.valid && kernel_i.ready;
  assign weight_load = load_enable && weights_loaded_q < WEIGHT_BEATS && !wgt_empty;
  // The shared feature FIFO belongs to the current tile until its last
  // vector has been loaded. Only then may the other macro consume from it.
  // Initially queue all 32 input beats, then load vector 0 into macro 0.
  // During RUN, the FIFO first contains the current tile's remaining vectors;
  // incoming next-tile beats are appended behind them. vector_q == 7 means
  // the last current vector is already in the macro, so the FIFO head now
  // belongs to the next tile. first_load may then feed the other macro.
  assign first_load = load_enable && first_sections_q < NUM_SECTIONS && !inp_empty &&
                      ((state_q == LOAD_FIRST && inputs_received_q == INPUT_BEATS) ||
                       (state_q == RUN && vector_q == 7));
  assign feature_load = state_q == RUN && compute_state_q == FEATURES && !inp_empty;
  // Prepared means all weights are in the macro, vector 0 is in its feature
  // buffer, and the other seven vectors have arrived and remain in the FIFO.
  // In LOAD_FIRST this describes the first tile, despite the signal name.
  assign next_loaded = weights_loaded_q == WEIGHT_BEATS &&
                       inputs_received_q == INPUT_BEATS && first_sections_q == NUM_SECTIONS;
  // A phase is one tile product, not the whole job or necessarily a completed
  // output tile. Wait for both computation and the parallel loader to finish.
  assign phase_complete = compute_state_q == DRAIN && results_q == 256 &&
                          (!has_next || next_loaded);
  // Normal tile clear resets only accumulators/selector. It preserves the
  // next tile already loaded in the other macro and queued in the FIFOs.
  assign acc_clear = state_q == CLEAR_TILE || (state_q == IDLE && start_i);

  // Combinational logic chooses the control pins for the current cycle.
  // Idle defaults prevent unintended reads/writes. Counters change in the
  // sequential block below, so each asserted load/compute acts at an edge.
  always_comb begin
    compe = '0;
    fcsn = '1;
    rcsn = '1;
    wcsn = '1;
    fa = '0;
    ra = '0;
    wa = '0;
    if (core_rst_n) begin
      if (weight_load) begin
        // WA[6:2] = row, WA[1:0] = section. Sequential section counts give
        // the required row-first order without separate row/section counters.
        wcsn[load_macro] = 1'b0;
        wa[load_macro] = weights_loaded_q[6:0];
      end
      if (first_load) begin
        fcsn[load_macro] = 1'b0;
        fa[load_macro] = first_sections_q[1:0];
      end
      if (state_q == RUN) begin
        if (compute_state_q == ROWS) begin
          // A compute command uses the whole 1024-bit row, so RA's section
          // bits are zero. One row command is issued per cycle, 32 per vector.
          compe[active_q] = 1'b1;
          rcsn[active_q] = 1'b0;
          ra[active_q] = {row_q, 2'b00};
        end
        if (feature_load) begin
          fcsn[active_q] = 1'b0;
          fa[active_q] = section_q;
        end
      end
    end
  end

  // Instantiate the actual arithmetic hardware once. Configuration is shared
  // by both macros, but their operation controls remain independent.
  // result_pop reports an output-FIFO word consumed by an accumulator; it is
  // not the external result_valid/result_ready tile handshake.
  cleopatra #(
    .SECTION_WIDTH(SECTION_WIDTH), .INP_FIFO_DEPTH(INP_FIFO_DEPTH),
    .WGT_FIFO_DEPTH(WGT_FIFO_DEPTH), .OUT_FIFO_DEPTH(OUT_FIFO_DEPTH)
  ) i_cleopatra (
    .clk(clk_i), .rst_n(core_rst_n), .sel(active_q),
    .COMPE_m0(compe[0]), .FCSN_m0(fcsn[0]),
    .MODE_m0(mode_q), .FA_m0(fa[0]), .ADDIN_m0(bias_q),
    .RA_m0(ra[0]), .WA_m0(wa[0]),
    .RCSN_m0(rcsn[0]), .RCSN0_m0(rcsn[0]), .RCSN1_m0(rcsn[0]),
    .RCSN2_m0(rcsn[0]), .RCSN3_m0(rcsn[0]),
    .WCSN_m0(wcsn[0]), .WEN_m0(wcsn[0]), .M_m0(mask_q),
    .compute_mask_m0(compute_mask_q), .sign_8b_m0(sign_q),
    .COMPE_m1(compe[1]), .FCSN_m1(fcsn[1]),
    .MODE_m1(mode_q), .FA_m1(fa[1]), .ADDIN_m1(bias_q),
    .RA_m1(ra[1]), .WA_m1(wa[1]),
    .RCSN_m1(rcsn[1]), .RCSN0_m1(rcsn[1]), .RCSN1_m1(rcsn[1]),
    .RCSN2_m1(rcsn[1]), .RCSN3_m1(rcsn[1]),
    .WCSN_m1(wcsn[1]), .WEN_m1(wcsn[1]), .M_m1(mask_q),
    .compute_mask_m1(compute_mask_q), .sign_8b_m1(sign_q),
    .inp_push(inp_push), .inp_data(input_i.data),
    .wgt_push(wgt_push), .wgt_data(kernel_i.data),
    .inp_full(inp_full), .inp_empty(inp_empty),
    .wgt_full(wgt_full), .wgt_empty(wgt_empty),
    .result_pop_o(result_pop), .clear(acc_clear), .acc_o(acc)
  );

  // Sequential logic stores progress. Reset/clear returns all bookkeeping
  // and Cleopatra to a common empty state so an aborted job cannot leak data.
  always_ff @(posedge clk_i or negedge core_rst_n) begin
    if (!core_rst_n) begin
      state_q <= IDLE;
      compute_state_q <= ROWS;
      k_size_q <= 0;
      l_size_q <= 0;
      q_size_q <= 0;
      k_q <= 0;
      l_q <= 0;
      q_q <= 0;
      mode_q <= 2'b11;
      sign_q <= 0;
      bias_q <= 0;
      mask_q <= '1;
      compute_mask_q <= 0;
      active_q <= 0;
      weights_received_q <= 0;
      weights_loaded_q <= 0;
      inputs_received_q <= 0;
      first_sections_q <= 0;
      vector_q <= 0;
      section_q <= 0;
      row_q <= 0;
      results_q <= 0;
      done_o <= 0;
    end else begin
      // Default low makes done_o a one-cycle pulse. Increment counters only
      // on actual transfers. State-transition assignments later in this block
      // take priority when a counter must restart for a new loading phase.
      done_o <= 0;
      if (inp_push) inputs_received_q <= inputs_received_q + 1'b1;
      if (wgt_push) weights_received_q <= weights_received_q + 1'b1;
      if (weight_load) weights_loaded_q <= weights_loaded_q + 1'b1;
      if (first_load) first_sections_q <= first_sections_q + 1'b1;
      if (result_pop) results_q <= results_q + 1'b1;
      case (state_q)
        IDLE: if (start_i && valid_config) begin
          // Divide dimensions by fixed tile sizes using right shifts.
          // The inner dimension is common to both matrices, hence one L count.
          k_size_q <= weight_rows_i >> 5;
          l_size_q <= weight_cols_i >> 7;
          q_size_q <= input_cols_i >> 3;
          k_q <= 0;
          l_q <= 0;
          q_q <= 0;
          mode_q <= mode_i;
          sign_q <= sign_8b_i;
          bias_q <= bias_i;
          mask_q <= write_mask_i;
          compute_mask_q <= compute_mask_i;
          active_q <= 0;
          weights_received_q <= 0;
          weights_loaded_q <= 0;
          inputs_received_q <= 0;
          first_sections_q <= 0;
          vector_q <= 0;
          section_q <= 0;
          row_q <= 0;
          results_q <= 0;
          compute_state_q <= ROWS;
          state_q <= LOAD_FIRST;
        end
        LOAD_FIRST: if (next_loaded) begin
          // Macro 0 has its kernel and first vector; seven vectors remain queued.
          // Reset loading counters for the NEXT tile without flushing FIFOs.
          weights_received_q <= 0;
          weights_loaded_q <= 0;
          inputs_received_q <= 0;
          first_sections_q <= 0;
          state_q <= RUN;
        end
        RUN: begin
          // Loading continues independently through weight_load/first_load
          // above. This nested FSM controls only the active macro's work.
          case (compute_state_q)
            ROWS: begin
              if (row_q == 31) begin
                row_q <= 0;
                if (vector_q == 7) compute_state_q <= DRAIN;
                else compute_state_q <= FEATURES;
              end else row_q <= row_q + 1'b1;
            end
            FEATURES: if (feature_load) begin
              // If the FIFO is empty, remain here without advancing FA.
              // Two-bit section_q wraps from 3 to 0 after the fourth transfer.
              section_q <= section_q + 1'b1;
              if (section_q == 3) begin
                vector_q <= vector_q + 1'b1;
                compute_state_q <= ROWS;
              end
            end
            // Stop issuing commands, but keep collecting delayed results.
            DRAIN: ;
            default: compute_state_q <= DRAIN;
          endcase
          // Never change the output mux until all 256 results are accumulated.
          if (phase_complete) begin
            // Intermediate l: keep accumulator sums and switch macros.
            // Last l: expose the complete output tile before clearing it.
            if (l_q == l_size_q-1) state_q <= PRESENT;
            else state_q <= ADVANCE;
          end
        end
        // result_valid_o is high in PRESENT. No compute/load is issued here,
        // so the entire tile remains stable for arbitrarily long backpressure.
        PRESENT: if (result_ready_i) state_q <= CLEAR_TILE;
        CLEAR_TILE: begin
          // acc_clear is high during this state; Cleopatra clears at this edge.
          // Only the final output tile ends the job and produces done_o.
          if (has_next) state_q <= ADVANCE;
          else begin
            state_q <= IDLE;
            done_o <= 1'b1;
          end
        end
        ADVANCE: begin
          // The other macro is fully prepared; advance in l-fastest order.
          // Example L=2,Q=2: (k,0,0), (k,0,1), (k,1,0), (k,1,1),
          // then (k+1,0,0). Reset compute progress and next-tile load counts.
          active_q <= ~active_q;
          if (l_q == l_size_q-1) begin
            l_q <= 0;
            if (q_q == q_size_q-1) begin
              q_q <= 0;
              k_q <= k_q + 1'b1;
            end else q_q <= q_q + 1'b1;
          end else l_q <= l_q + 1'b1;
          weights_received_q <= 0;
          weights_loaded_q <= 0;
          inputs_received_q <= 0;
          first_sections_q <= 0;
          vector_q <= 0;
          section_q <= 0;
          row_q <= 0;
          results_q <= 0;
          compute_state_q <= ROWS;
          state_q <= RUN;
        end
        default: state_q <= IDLE;
      endcase
    end
  end

  // Simulation checks only: these explain unsupported setup choices rather
  // than creating extra datapath circuitry in synthesis.
  // synthesis translate_off
  initial begin
    assert (SECTION_WIDTH == 256 && INP_FIFO_DEPTH >= INPUT_BEATS)
      else $fatal(1, "Datapath requires 256-bit sections and an input FIFO of at least 32 sections");
  end
  always @(posedge clk_i) begin
    if (core_rst_n && state_q == IDLE && start_i)
      assert (valid_config) else $error("Invalid dimensions or mode: complete 8-bit tiles required");
  end
  // synthesis translate_on
endmodule
