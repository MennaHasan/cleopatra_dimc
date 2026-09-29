/* Row-major memory <-> Cleopatra tiles.
 * HCI source/sink IP performs the actual memory requests and handshakes.
 * The input tile buffer transposes 128 rows of 8 bytes into 8 vectors of
 * 128 bytes. Weight sections need only a byte-order reversal. Output rows
 * already contain eight 32-bit results and are written in one 256-bit beat.
 *
 * Three independent HCI ports: inputs 64 bits, weights/results 256 bits.
 * No full-matrix buffer or software tiling is required. Only one input tile
 * is staged here. Macro double buffering remains inside the datapath.
 */
module dimc_streamer
  import dimc_package::*;
  import hci_package::*;
#(
  parameter hci_size_parameter_t INPUT_SIZE = '{DW:64, AW:32, BW:8, UW:1, IW:1, EW:0, EHW:0},
  parameter hci_size_parameter_t KERNEL_SIZE = '{DW:256, AW:32, BW:8, UW:1, IW:1, EW:0, EHW:0},
  parameter hci_size_parameter_t OUTPUT_SIZE = '{DW:256, AW:32, BW:8, UW:1, IW:1, EW:0, EHW:0}
)(
  input logic clk_i, rst_ni, clear_i, abort_i, start_i,
  input wire dimc_config_t config_i,
  output dimc_streamer_flags_t flags_o,
  hci_core_intf.initiator input_tcdm,
  hci_core_intf.initiator kernel_tcdm,
  hci_core_intf.initiator output_tcdm,
  hwpe_stream_intf_stream.source input_o,
  hwpe_stream_intf_stream.source kernel_o,
  input wire [31:0] result_i [0:31][0:7],
  input logic result_valid_i,
  output logic result_ready_o
);
  hci_streamer_ctrl_t input_ctrl, kernel_ctrl, output_ctrl;
  hci_streamer_flags_t input_flags, kernel_flags, output_flags;
  hwpe_stream_intf_stream #(.DATA_WIDTH(64)) input_mem (.clk(clk_i));
  hwpe_stream_intf_stream #(.DATA_WIDTH(256)) kernel_mem (.clk(clk_i));
  hwpe_stream_intf_stream #(.DATA_WIDTH(256)) output_mem (.clk(clk_i));

  // A pair is one weight[k][l] / input[l][q] combination. The two sources
  // launch together but complete independently. All indices advance only
  // after both have delivered that pair; stream backpressure preserves order.
  typedef enum logic [2:0] {P_IDLE, P_START, P_TRANSFER, P_DRAIN, P_DONE} pair_state_t;
  typedef enum logic [1:0] {I_READ, I_SEND, I_DONE} input_state_t;
  typedef enum logic [1:0] {O_IDLE, O_SEND, O_WAIT, O_ACK} output_state_t;
  pair_state_t pair_q;
  input_state_t input_q;
  output_state_t output_q;
  dimc_config_t cfg_q;
  logic [31:0] k_q, l_q, q_q, out_k_q, out_q_q;
  logic [31:0] weight_base_q, weight_group_q, input_base_q, input_group_q;
  logic [31:0] output_base_q, output_group_q;
  logic [63:0] input_tile_q [0:127];
  logic [6:0] input_row_q;
  logic [4:0] input_beat_q, output_row_q;
  logic input_done_q, kernel_done_q, output_finished_q, aborting_q, aborting;
  logic last_pair, last_output, engines_idle;

  assign aborting = abort_i || aborting_q;
  assign last_pair = k_q == (cfg_q.weight_rows>>5)-1 &&
                     l_q == (cfg_q.weight_cols>>7)-1 && q_q == (cfg_q.input_cols>>3)-1;
  assign last_output = out_k_q == (cfg_q.weight_rows>>5)-1 &&
                       out_q_q == (cfg_q.input_cols>>3)-1;
  assign engines_idle = input_flags.ready_start && kernel_flags.ready_start &&
                        output_flags.ready_start && output_q == O_IDLE;
  // During abort, drop outstanding read responses and finish any active
  // output burst before announcing quiescence. The controller then clears us.
  assign flags_o.busy = aborting ? !engines_idle : pair_q != P_IDLE;

  always_comb begin
    input_ctrl = '0;
    kernel_ctrl = '0;
    output_ctrl = '0;
    input_ctrl.req_start = pair_q == P_START && input_flags.ready_start &&
                           kernel_flags.ready_start && !aborting;
    kernel_ctrl.req_start = input_ctrl.req_start;
    // A 64-bit read fetches exactly the eight columns of this input tile.
    // Step by a complete input-matrix row to gather the next eight bytes.
    input_ctrl.addressgen_ctrl.base_addr = input_base_q;
    input_ctrl.addressgen_ctrl.tot_len = 128;
    input_ctrl.addressgen_ctrl.d0_len = 128;
    input_ctrl.addressgen_ctrl.d0_stride = cfg_q.input_cols;
    input_ctrl.addressgen_ctrl.dim_enable_1h = 4'b0000;
    // Four sections per weight row, then skip to the next full-matrix row.
    kernel_ctrl.addressgen_ctrl.base_addr = weight_base_q;
    kernel_ctrl.addressgen_ctrl.tot_len = 128;
    kernel_ctrl.addressgen_ctrl.d0_len = 4;
    kernel_ctrl.addressgen_ctrl.d0_stride = 32;
    kernel_ctrl.addressgen_ctrl.d1_len = 32;
    kernel_ctrl.addressgen_ctrl.d1_stride = cfg_q.weight_cols;
    kernel_ctrl.addressgen_ctrl.dim_enable_1h = 4'b0001;
    // Each memory beat stores one tile row (8 x 32 bits). Row stride is the
    // full result width in bytes, leaving other output tiles untouched.
    output_ctrl.req_start = output_q == O_IDLE && result_valid_i &&
                            pair_q != P_IDLE && output_flags.ready_start && !aborting;
    output_ctrl.addressgen_ctrl.base_addr = output_base_q;
    output_ctrl.addressgen_ctrl.tot_len = 32;
    output_ctrl.addressgen_ctrl.d0_len = 32;
    output_ctrl.addressgen_ctrl.d0_stride = cfg_q.input_cols << 2;
    output_ctrl.addressgen_ctrl.dim_enable_1h = 4'b0000;
  end

  hci_core_source #(
    .MISALIGNED_ACCESSES(0), .DIM_ENABLE_1H(4'b0000), .HCI_SIZE_tcdm(INPUT_SIZE)
  ) i_input_source (
    .clk_i, .rst_ni, .test_mode_i(1'b0), .clear_i, .enable_i(1'b1),
    .tcdm(input_tcdm), .stream(input_mem), .ctrl_i(input_ctrl), .flags_o(input_flags)
  );
  hci_core_source #(
    .MISALIGNED_ACCESSES(0), .DIM_ENABLE_1H(4'b0001), .HCI_SIZE_tcdm(KERNEL_SIZE)
  ) i_kernel_source (
    .clk_i, .rst_ni, .test_mode_i(1'b0), .clear_i, .enable_i(1'b1),
    .tcdm(kernel_tcdm), .stream(kernel_mem), .ctrl_i(kernel_ctrl), .flags_o(kernel_flags)
  );
  hci_core_sink #(
    .MISALIGNED_ACCESSES(0), .TCDM_FIFO_DEPTH(0), .DIM_ENABLE_1H(4'b0000),
    .HCI_SIZE_tcdm(OUTPUT_SIZE)
  ) i_output_sink (
    .clk_i, .rst_ni, .test_mode_i(1'b0), .clear_i, .enable_i(1'b1),
    .tcdm(output_tcdm), .stream(output_mem), .ctrl_i(output_ctrl), .flags_o(output_flags)
  );

  // HCI uses little-endian byte lanes; Cleopatra's section format is MSB-first.
  for (genvar b=0; b<32; b++) begin : gen_weight_bytes
    assign kernel_o.data[255-b*8 -: 8] = kernel_mem.data[b*8 +: 8];
  end
  assign kernel_o.strb = '1;
  assign kernel_o.valid = kernel_mem.valid && !aborting && !clear_i;
  assign kernel_mem.ready = aborting || kernel_o.ready;
  assign input_mem.ready = aborting || (pair_q == P_TRANSFER && input_q == I_READ);
  // input_beat[4:2] is column 0..7, input_beat[1:0] is section 0..3.
  // Reading 32 different buffered rows assembles one vector section.
  for (genvar b=0; b<32; b++) begin : gen_input_bytes
    assign input_o.data[255-b*8 -: 8] =
      input_tile_q[{input_beat_q[1:0], 5'b0}+b][input_beat_q[4:2]*8 +: 8];
  end
  assign input_o.strb = '1;
  assign input_o.valid = pair_q == P_TRANSFER && input_q == I_SEND && !aborting && !clear_i;
  for (genvar c=0; c<8; c++) begin : gen_output_words
    assign output_mem.data[c*32 +: 32] = result_i[output_row_q][c];
  end
  assign output_mem.strb = '1;
  assign output_mem.valid = output_q == O_SEND;
  // Wait for memory grants, not merely stream presentation, before allowing
  // the datapath to clear the accumulators. There is no extra output FIFO.
  assign result_ready_o = output_q == O_ACK;

  // Tile data need not reset: all 128 rows are overwritten before I_SEND.
  always_ff @(posedge clk_i) begin
    if (input_mem.valid && input_mem.ready && !aborting && !clear_i)
      input_tile_q[input_row_q] <= input_mem.data;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      pair_q <= P_IDLE; input_q <= I_READ; output_q <= O_IDLE;
      cfg_q <= '0;
      k_q <= 0; l_q <= 0; q_q <= 0; out_k_q <= 0; out_q_q <= 0;
      weight_base_q <= 0; weight_group_q <= 0; input_base_q <= 0; input_group_q <= 0;
      output_base_q <= 0; output_group_q <= 0;
      input_row_q <= 0; input_beat_q <= 0; output_row_q <= 0;
      input_done_q <= 0; kernel_done_q <= 0; output_finished_q <= 0;
      aborting_q <= 0; flags_o.done <= 0;
    end else if (clear_i) begin
      pair_q <= P_IDLE; input_q <= I_READ; output_q <= O_IDLE;
      aborting_q <= 0; flags_o.done <= 0;
      input_done_q <= 0; kernel_done_q <= 0; output_finished_q <= 0;
      input_row_q <= 0; input_beat_q <= 0; output_row_q <= 0;
    end else begin
      flags_o.done <= 0;
      if (abort_i) aborting_q <= 1;
      if (input_flags.done) input_done_q <= 1;
      if (kernel_flags.done) kernel_done_q <= 1;
      if (!aborting) begin
        case (pair_q)
          P_IDLE: if (start_i) begin
            cfg_q <= config_i;
            k_q <= 0; l_q <= 0; q_q <= 0; out_k_q <= 0; out_q_q <= 0;
            weight_base_q <= config_i.kernel_addr; weight_group_q <= config_i.kernel_addr;
            input_base_q <= config_i.input_addr; input_group_q <= config_i.input_addr;
            output_base_q <= config_i.output_addr; output_group_q <= config_i.output_addr;
            input_row_q <= 0; input_beat_q <= 0;
            input_done_q <= 0; kernel_done_q <= 0; output_finished_q <= 0;
            input_q <= I_READ;
            pair_q <= P_START;
          end
          P_START: if (input_ctrl.req_start) pair_q <= P_TRANSFER;
          P_TRANSFER: begin
            case (input_q)
              I_READ: if (input_mem.valid && input_mem.ready) begin
                input_row_q <= input_row_q + 1'b1;
                if (input_row_q == 127) input_q <= I_SEND;
              end
              I_SEND: if (input_o.valid && input_o.ready) begin
                input_beat_q <= input_beat_q + 1'b1;
                if (input_beat_q == 31) input_q <= I_DONE;
              end
              I_DONE: ;
              default: input_q <= I_READ;
            endcase
            if (input_q == I_DONE && input_done_q && kernel_done_q) pair_q <= P_DRAIN;
          end
          P_DRAIN: begin
            if (last_pair) pair_q <= P_DONE;
            else begin
              // Increment addresses instead of multiplying tile indices each cycle.
              if (l_q != (cfg_q.weight_cols>>7)-1) begin
                l_q <= l_q + 1;
                weight_base_q <= weight_base_q + 128;
                input_base_q <= input_base_q + (cfg_q.input_cols << 7);
              end else begin
                l_q <= 0;
                if (q_q != (cfg_q.input_cols>>3)-1) begin
                  q_q <= q_q + 1;
                  weight_base_q <= weight_group_q;
                  input_group_q <= input_group_q + 8;
                  input_base_q <= input_group_q + 8;
                end else begin
                  q_q <= 0; k_q <= k_q + 1;
                  weight_group_q <= weight_group_q + (cfg_q.weight_cols << 5);
                  weight_base_q <= weight_group_q + (cfg_q.weight_cols << 5);
                  input_group_q <= cfg_q.input_addr;
                  input_base_q <= cfg_q.input_addr;
                end
              end
              input_done_q <= 0; kernel_done_q <= 0;
              input_row_q <= 0; input_beat_q <= 0; input_q <= I_READ;
              pair_q <= P_START;
            end
          end
          P_DONE: if (output_finished_q && output_q == O_IDLE) begin
            flags_o.done <= 1;
            pair_q <= P_IDLE;
          end
          default: pair_q <= P_IDLE;
        endcase
      end
      // An already started output burst finishes even during abort. This keeps
      // a stalled request stable and makes soft-clear safe with memory latency.
      case (output_q)
        O_IDLE: if (output_ctrl.req_start) begin
          output_row_q <= 0;
          output_q <= O_SEND;
        end
        O_SEND: if (output_mem.valid && output_mem.ready) begin
          output_row_q <= output_row_q + 1'b1;
          if (output_row_q == 31) output_q <= O_WAIT;
        end
        O_WAIT: if (output_flags.done) output_q <= O_ACK;
        O_ACK: begin
          output_q <= O_IDLE;
          if (last_output) output_finished_q <= 1;
          else if (out_q_q != (cfg_q.input_cols>>3)-1) begin
            out_q_q <= out_q_q + 1;
            output_base_q <= output_base_q + 32;
          end else begin
            out_q_q <= 0; out_k_q <= out_k_q + 1;
            output_group_q <= output_group_q + (cfg_q.input_cols << 7);
            output_base_q <= output_group_q + (cfg_q.input_cols << 7);
          end
        end
        default: output_q <= O_IDLE;
      endcase
    end
  end
endmodule
