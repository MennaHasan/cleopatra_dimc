/* Standalone accelerator: HWPE configuration + three HCI memory ports.
 * Memory interfaces deliberately have different widths: inputs fetch exactly
 * eight columns (64 bits); weights/results transfer one 256-bit section/row.
 * All addresses are byte addresses and all three ports share an address space.
 */
module dimc_top
  import dimc_package::*;
  import hwpe_ctrl_package::*;
  import hci_package::*;
#(
  parameter int unsigned N_CORES = 2,
  parameter int unsigned N_CONTEXT = 2,
  parameter int unsigned ID = 10,
  parameter hci_size_parameter_t INPUT_SIZE = '{DW:64, AW:32, BW:8, UW:1, IW:1, EW:0, EHW:0},
  parameter hci_size_parameter_t KERNEL_SIZE = '{DW:256, AW:32, BW:8, UW:1, IW:1, EW:0, EHW:0},
  parameter hci_size_parameter_t OUTPUT_SIZE = '{DW:256, AW:32, BW:8, UW:1, IW:1, EW:0, EHW:0}
)(
  input logic clk_i, rst_ni,
  output logic busy_o,
  output logic [N_CORES-1:0][REGFILE_N_EVT-1:0] evt_o,
  hwpe_ctrl_intf_periph.slave periph,
  hci_core_intf.initiator input_tcdm,
  hci_core_intf.initiator kernel_tcdm,
  hci_core_intf.initiator output_tcdm
);
  dimc_config_t config_;
  dimc_streamer_flags_t streamer_flags;
  logic clear, abort_job, dp_start, stream_start, dp_ready, dp_done;
  logic result_valid, result_ready;
  logic [31:0] result [0:31][0:7];
  hwpe_stream_intf_stream #(.DATA_WIDTH(256)) input_stream (.clk(clk_i));
  hwpe_stream_intf_stream #(.DATA_WIDTH(256)) kernel_stream (.clk(clk_i));

  dimc_ctrl #(.N_CORES(N_CORES), .N_CONTEXT(N_CONTEXT), .ID(ID)) i_ctrl (
    .clk_i, .rst_ni, .periph, .evt_o, .config_o(config_),
    .datapath_start_o(dp_start), .streamer_start_o(stream_start),
    .clear_o(clear), .abort_o(abort_job), .busy_o,
    .datapath_ready_i(dp_ready), .datapath_done_i(dp_done), .streamer_flags_i(streamer_flags)
  );
  dimc_datapath i_datapath (
    .clk_i, .rst_ni, .clear_i(clear), .start_i(dp_start),
    .weight_rows_i(config_.weight_rows), .weight_cols_i(config_.weight_cols),
    .input_rows_i(config_.input_rows), .input_cols_i(config_.input_cols),
    .mode_i(config_.mode), .sign_8b_i(config_.sign_8b), .bias_i(config_.bias),
    .write_mask_i(config_.write_mask), .compute_mask_i(config_.compute_mask),
    .input_i(input_stream), .kernel_i(kernel_stream),
    .ready_o(dp_ready), .done_o(dp_done), .result_o(result),
    .result_valid_o(result_valid), .result_ready_i(result_ready)
  );
  dimc_streamer #(.INPUT_SIZE(INPUT_SIZE), .KERNEL_SIZE(KERNEL_SIZE), .OUTPUT_SIZE(OUTPUT_SIZE))
  i_streamer (
    .clk_i, .rst_ni, .clear_i(clear), .abort_i(abort_job), .start_i(stream_start),
    .config_i(config_), .flags_o(streamer_flags), .input_tcdm, .kernel_tcdm, .output_tcdm,
    .input_o(input_stream), .kernel_o(kernel_stream),
    .result_i(result), .result_valid_i(result_valid), .result_ready_o(result_ready)
  );
  // synthesis translate_off
  initial begin
    assert (INPUT_SIZE.DW == 64 && KERNEL_SIZE.DW == 256 && OUTPUT_SIZE.DW == 256)
      else $fatal(1, "DIMC memory widths must be input=64, weight=256, output=256");
  end
  // synthesis translate_on
endmodule
