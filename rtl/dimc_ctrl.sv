/* Software-facing job controller and single-macro tile sequencer. */
module dimc_ctrl
  import dimc_package::*;
  import hwpe_ctrl_package::*;
#(
  parameter int unsigned N_CORES = 2,
  parameter int unsigned N_CONTEXT = 2,
  parameter int unsigned ID = 10
)(
  input logic clk_i, rst_ni,
  hwpe_ctrl_intf_periph.slave periph,
  output logic [N_CORES-1:0][REGFILE_N_EVT-1:0] evt_o,
  output dimc_config_t config_o,
  output logic streamer_start_o, clear_o, abort_o, busy_o,
  input wire dimc_streamer_flags_t streamer_flags_i,
  hwpe_stream_intf_stream.sink input_i,
  hwpe_stream_intf_stream.sink kernel_i,
  input logic macro_readyn_i,
  output logic macro_compe_o, macro_fcsn_o,
  output logic [1:0] macro_mode_o, macro_fa_o,
  output logic [31:0] macro_addin_o,
  output logic [6:0] macro_ra_o, macro_wa_o,
  output logic macro_rcsn_o,
  output logic [3:0] macro_rcsn_sections_o,
  output logic macro_wcsn_o, macro_wen_o,
  output logic [255:0] macro_mask_o,
  output logic [9:0] macro_compute_mask_o,
  output logic [1:0] macro_sign_8b_o,
  output logic accumulator_clear_o,
  output logic result_capture_o,
  output logic result_valid_o,
  input logic result_ready_i
);
  ctrl_slave_t slave_ctrl;
  flags_slave_t slave_flags;
  ctrl_regfile_t reg_file;
  dimc_config_t programmed, config_q;
  logic soft_clear, valid_config, error_q, module_done_q, module_busy;
  logic weight_fire, input_fire, macro_result_valid, capture_window;
  logic [65:0] weight_end, input_end, output_end;
  logic [31:0] k_size_q, l_size_q, q_size_q;
  logic [31:0] k_q, l_q, q_q;
  logic [7:0] weight_count_q;
  logic [1:0] section_q;
  logic [2:0] vector_q;
  logic [4:0] row_q;
  logic [5:0] result_count_q;

  typedef enum logic [3:0] {
    IDLE, START, LOAD_WEIGHT, LOAD_VECTOR, COMPUTE, DRAIN,
    ADVANCE, PRESENT, WAIT_STREAM, FINISH, ABORT, CLEAR
  } state_t;
  state_t state_q;

  hwpe_ctrl_slave #(
    .N_CORES(N_CORES), .N_CONTEXT(N_CONTEXT), .N_IO_REGS(DIMC_NB_REGS),
    .N_GENERIC_REGS(0), .ID_WIDTH(ID), .REGFILE_SCM(0)
  ) i_slave (
    .clk_i, .rst_ni, .clear_o(soft_clear), .cfg(periph),
    .ctrl_i(slave_ctrl), .flags_o(slave_flags), .reg_file, .counter_pending()
  );

  always_comb begin
    programmed = '0;
    programmed.input_addr = reg_file.hwpe_params[DIMC_REG_INPUT_ADDR];
    programmed.kernel_addr = reg_file.hwpe_params[DIMC_REG_KERNEL_ADDR];
    programmed.output_addr = reg_file.hwpe_params[DIMC_REG_OUTPUT_ADDR];
    programmed.weight_rows = reg_file.hwpe_params[DIMC_REG_WEIGHT_ROWS];
    programmed.weight_cols = reg_file.hwpe_params[DIMC_REG_WEIGHT_COLS];
    programmed.input_rows = reg_file.hwpe_params[DIMC_REG_INPUT_ROWS];
    programmed.input_cols = reg_file.hwpe_params[DIMC_REG_INPUT_COLS];
    programmed.mode = reg_file.hwpe_params[DIMC_REG_FORMAT][1:0];
    programmed.sign_8b = reg_file.hwpe_params[DIMC_REG_FORMAT][3:2];
    programmed.bias = reg_file.hwpe_params[DIMC_REG_BIAS];
    programmed.compute_mask = reg_file.hwpe_params[DIMC_REG_COMPUTE_MASK][9:0];
    for (int i=0; i<8; i++)
      programmed.write_mask[i*32 +: 32] = reg_file.hwpe_params[DIMC_REG_WRITE_MASK+i];
  end

  assign weight_end = 66'(programmed.kernel_addr) +
                      66'(programmed.weight_rows)*66'(programmed.weight_cols);
  assign input_end = 66'(programmed.input_addr) +
                     66'(programmed.input_rows)*66'(programmed.input_cols);
  assign output_end = 66'(programmed.output_addr) +
                      66'(programmed.weight_rows)*66'(programmed.input_cols)*66'd4;
  assign valid_config = programmed.weight_rows != 0 && programmed.weight_cols != 0 &&
      programmed.input_cols != 0 && programmed.weight_cols == programmed.input_rows &&
      programmed.weight_rows[4:0] == 0 && programmed.weight_cols[6:0] == 0 &&
      programmed.input_cols[2:0] == 0 && programmed.input_addr[2:0] == 0 &&
      programmed.kernel_addr[4:0] == 0 && programmed.output_addr[4:0] == 0 &&
      weight_end <= 66'h100000000 && input_end <= 66'h100000000 &&
      output_end <= 66'h100000000;

  assign config_o = config_q;
  assign busy_o = state_q != IDLE;
  assign streamer_start_o = state_q == START;
  assign clear_o = state_q == CLEAR;
  assign abort_o = soft_clear || state_q == ABORT;
  assign result_valid_o = state_q == PRESENT;
  assign capture_window = (state_q == COMPUTE || state_q == DRAIN) && !abort_o;
  assign macro_result_valid = !macro_readyn_i && capture_window;
  assign result_capture_o = macro_result_valid;
  assign weight_fire = kernel_i.valid && kernel_i.ready;
  assign input_fire = input_i.valid && input_i.ready;
  assign accumulator_clear_o = state_q == START ||
                               (state_q == PRESENT && result_ready_i) ||
                               state_q == CLEAR;
  assign module_busy = busy_o && !error_q && !module_done_q;
  assign evt_o = slave_flags.evt[N_CORES-1:0];

  always_comb begin
    input_i.ready = state_q == LOAD_VECTOR && !abort_o;
    kernel_i.ready = state_q == LOAD_WEIGHT && !abort_o;

    macro_compe_o = 1'b0;
    macro_fcsn_o = 1'b1;
    macro_mode_o = config_q.mode;
    macro_fa_o = section_q;
    macro_addin_o = l_q == 0 ? config_q.bias : 32'b0;
    macro_ra_o = {row_q, 2'b00};
    macro_wa_o = weight_count_q[6:0];
    macro_rcsn_o = 1'b1;
    macro_rcsn_sections_o = '1;
    macro_wcsn_o = 1'b1;
    macro_wen_o = 1'b1;
    macro_mask_o = config_q.write_mask;
    macro_compute_mask_o = config_q.compute_mask;
    macro_sign_8b_o = config_q.sign_8b;

    if (input_fire) macro_fcsn_o = 1'b0;
    if (weight_fire) begin
      macro_wcsn_o = 1'b0;
      macro_wen_o = 1'b0;
    end
    if (state_q == COMPUTE && !abort_o) begin
      macro_compe_o = 1'b1;
      macro_rcsn_o = 1'b0;
      macro_rcsn_sections_o = '0;
    end

    slave_ctrl = '0;
    slave_ctrl.done = state_q == FINISH && !soft_clear;
    slave_ctrl.evt = state_q == FINISH && error_q && !soft_clear;
    // 0x18: bit 0 overall busy, bit 1 error, bit 2 module busy,
    // bit 4 remembered module completion (cleared by next job/soft clear).
    slave_ctrl.ext_flags = {28'b0, module_done_q, 1'b0, module_busy, error_q, busy_o};
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= IDLE;
      config_q <= '0;
      error_q <= 0;
      module_done_q <= 0;
      k_size_q <= 0; l_size_q <= 0; q_size_q <= 0;
      k_q <= 0; l_q <= 0; q_q <= 0;
      weight_count_q <= 0; section_q <= 0; vector_q <= 0; row_q <= 0;
      result_count_q <= 0;
    end else if (soft_clear) begin
      state_q <= ABORT;
      error_q <= 0;
      module_done_q <= 0;
      weight_count_q <= 0; section_q <= 0; vector_q <= 0; row_q <= 0;
      result_count_q <= 0;
    end else begin
      if (macro_result_valid) result_count_q <= result_count_q + 1'b1;

      case (state_q)
        IDLE: if (slave_flags.start) begin
          config_q <= programmed;
          error_q <= !valid_config;
          module_done_q <= 0;
          if (valid_config) begin
            k_size_q <= programmed.weight_rows >> 5;
            l_size_q <= programmed.weight_cols >> 7;
            q_size_q <= programmed.input_cols >> 3;
            k_q <= 0; l_q <= 0; q_q <= 0;
            weight_count_q <= 0; section_q <= 0; vector_q <= 0; row_q <= 0;
            result_count_q <= 0;
            state_q <= START;
          end else state_q <= FINISH;
        end
        START: state_q <= LOAD_WEIGHT;
        LOAD_WEIGHT: if (weight_fire) begin
          if (weight_count_q == 127) begin
            weight_count_q <= 0;
            section_q <= 0;
            state_q <= LOAD_VECTOR;
          end else weight_count_q <= weight_count_q + 1'b1;
        end
        LOAD_VECTOR: if (input_fire) begin
          if (section_q == 3) begin
            section_q <= 0;
            row_q <= 0;
            result_count_q <= 0;
            state_q <= COMPUTE;
          end else section_q <= section_q + 1'b1;
        end
        COMPUTE: if (row_q == 31) begin
          row_q <= 0;
          state_q <= DRAIN;
        end else row_q <= row_q + 1'b1;
        DRAIN: if (macro_result_valid && result_count_q == 31) begin
          result_count_q <= 0;
          if (vector_q == 7) begin
            vector_q <= 0;
            if (l_q == l_size_q-1) state_q <= PRESENT;
            else state_q <= ADVANCE;
          end else begin
            vector_q <= vector_q + 1'b1;
            section_q <= 0;
            state_q <= LOAD_VECTOR;
          end
        end
        ADVANCE: begin
          l_q <= l_q + 1'b1;
          weight_count_q <= 0; section_q <= 0; vector_q <= 0; row_q <= 0;
          result_count_q <= 0;
          state_q <= LOAD_WEIGHT;
        end
        PRESENT: if (result_ready_i) begin
          l_q <= 0;
          weight_count_q <= 0; section_q <= 0; vector_q <= 0; row_q <= 0;
          result_count_q <= 0;
          if (k_q == k_size_q-1 && q_q == q_size_q-1) state_q <= WAIT_STREAM;
          else begin
            if (q_q == q_size_q-1) begin
              q_q <= 0;
              k_q <= k_q + 1'b1;
            end else q_q <= q_q + 1'b1;
            state_q <= LOAD_WEIGHT;
          end
        end
        WAIT_STREAM: if (streamer_flags_i.done) begin
          module_done_q <= 1;
          state_q <= FINISH;
        end
        FINISH: state_q <= IDLE;
        ABORT: if (!streamer_flags_i.busy) state_q <= CLEAR;
        CLEAR: state_q <= IDLE;
        default: state_q <= IDLE;
      endcase
    end
  end
endmodule
