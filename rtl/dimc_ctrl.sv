/* Software-facing job controller. HWPE-Ctrl owns register contexts/events;
 * this module validates and latches each job, then coordinates its lifetime.
 * Computation scheduling remains inside dimc_datapath. Memory tile scheduling
 * remains inside dimc_streamer. Completion includes the final memory write.
 */
module dimc_ctrl
  import dimc_package::*;
  import hwpe_ctrl_package::*;
#(
  parameter int unsigned N_CORES = 2,
  parameter int unsigned N_CONTEXT = 2,
  parameter int unsigned ID = 10
)(
  input logic clk_i, rst_ni, test_mode_i,
  hwpe_ctrl_intf_periph.slave periph,
  output logic [N_CORES-1:0][REGFILE_N_EVT-1:0] evt_o,
  output dimc_config_t config_o,
  output logic datapath_start_o, streamer_start_o,
  output logic clear_o, abort_o, busy_o,
  input logic datapath_ready_i, datapath_done_i,
  input wire dimc_streamer_flags_t streamer_flags_i
);
  ctrl_slave_t slave_ctrl;
  flags_slave_t slave_flags;
  ctrl_regfile_t reg_file;
  dimc_config_t programmed, config_q;
  logic soft_clear, valid_config, error_q, dp_done_q, stream_done_q;
  // Use wide arithmetic only for validation, so invalid 32-bit address ranges
  // cannot silently wrap and access unrelated memory.
  logic [65:0] weight_end, input_end, output_end;
  typedef enum logic [2:0] {IDLE, START, WAIT_READY, RUN, FINISH, ABORT, CLEAR} state_t;
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
      programmed.input_cols[2:0] == 0 && programmed.mode == 2'b11 &&
      programmed.input_addr[2:0] == 0 && programmed.kernel_addr[4:0] == 0 &&
      programmed.output_addr[4:0] == 0 &&
      weight_end <= 66'h100000000 && input_end <= 66'h100000000 && output_end <= 66'h100000000;

  assign config_o = config_q;
  assign busy_o = state_q != IDLE;
  assign datapath_start_o = state_q == START && !soft_clear;
  assign streamer_start_o = state_q == WAIT_READY && datapath_ready_i && !soft_clear;
  // Soft clear is drained before resetting the engines: an old memory response
  // must never be mistaken for data from the next job. In-flight writes finish.
  assign abort_o = soft_clear || state_q == ABORT;
  assign clear_o = state_q == CLEAR;
  assign evt_o = slave_flags.evt[N_CORES-1:0];
  always_comb begin
    slave_ctrl = '0;
    slave_ctrl.done = state_q == FINISH && !soft_clear;
    slave_ctrl.evt = state_q == FINISH && error_q && !soft_clear;
    // Read the HWPE extension register at 0x18: bit 0 busy, bit 1 config error.
    slave_ctrl.ext_flags = {30'b0, error_q, busy_o};
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= IDLE;
      config_q <= '0;
      error_q <= 0;
      dp_done_q <= 0;
      stream_done_q <= 0;
    end else if (soft_clear) begin
      state_q <= ABORT;
      error_q <= 0;
      dp_done_q <= 0;
      stream_done_q <= 0;
    end else begin
      if (datapath_done_i) dp_done_q <= 1;
      if (streamer_flags_i.done) stream_done_q <= 1;
      case (state_q)
        IDLE: if (slave_flags.start) begin
          config_q <= programmed;
          error_q <= !valid_config;
          dp_done_q <= 0;
          stream_done_q <= 0;
          state_q <= valid_config ? START : FINISH;
        end
        START: state_q <= WAIT_READY;
        WAIT_READY: if (datapath_ready_i) state_q <= RUN;
        RUN: if ((dp_done_q || datapath_done_i) &&
                 (stream_done_q || streamer_flags_i.done)) state_q <= FINISH;
        FINISH: state_q <= IDLE;
        ABORT: if (!streamer_flags_i.busy) state_q <= CLEAR;
        CLEAR: state_q <= IDLE;
        default: state_q <= IDLE;
      endcase
    end
  end
endmodule
