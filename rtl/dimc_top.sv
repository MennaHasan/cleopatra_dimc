/* One DIMC module with two macros, controlled as one software job.
 * One shared 256-bit HCI port serves its input, weight and output streamers.
 */
module dimc_top
  import dimc_package::*;
  import hwpe_ctrl_package::*;
  import hci_package::*;
#(
  parameter int unsigned N_CORES = 2,
  parameter int unsigned N_CONTEXT = 2,
  parameter int unsigned ID = 10,
  parameter hci_size_parameter_t INPUT_SIZE = '{DW:256, AW:32, BW:8, UW:1, IW:1, EW:0, EHW:0},
  parameter hci_size_parameter_t KERNEL_SIZE = '{DW:256, AW:32, BW:8, UW:1, IW:1, EW:0, EHW:0},
  parameter hci_size_parameter_t OUTPUT_SIZE = '{DW:256, AW:32, BW:8, UW:1, IW:1, EW:0, EHW:0}
)(
  input logic clk_i, rst_ni,
  output logic busy_o,
  output logic [N_CORES-1:0][REGFILE_N_EVT-1:0] evt_o,
  hwpe_ctrl_intf_periph.slave periph,
  hci_core_intf.initiator tcdm
);
  dimc_config_t config_;
  dimc_streamer_flags_t streamer_flags;
  logic clear, abort_job, dp_start, stream_start;
  logic dp_ready, dp_done;

  dimc_ctrl #(.N_CORES(N_CORES), .N_CONTEXT(N_CONTEXT), .ID(ID)) i_ctrl (
    .clk_i, .rst_ni, .periph, .evt_o, .config_o(config_),
    .datapath_start_o(dp_start), .streamer_start_o(stream_start),
    .clear_o(clear), .abort_o(abort_job), .busy_o,
    .datapath_ready_i(dp_ready), .datapath_done_i(dp_done), .streamer_flags_i(streamer_flags)
  );
  dimc_module #(
    .INPUT_SIZE(INPUT_SIZE), .KERNEL_SIZE(KERNEL_SIZE), .OUTPUT_SIZE(OUTPUT_SIZE)
  ) i_module (
    .clk_i, .rst_ni, .clear_i(clear), .abort_i(abort_job),
    .datapath_start_i(dp_start), .streamer_start_i(stream_start), .config_i(config_),
    .datapath_ready_o(dp_ready), .datapath_done_o(dp_done),
    .streamer_flags_o(streamer_flags),
    .tcdm(tcdm)
  );
  // synthesis translate_off
  initial begin
    assert (INPUT_SIZE.DW == 256 && KERNEL_SIZE.DW == 256 && OUTPUT_SIZE.DW == 256)
      else $fatal(1, "DIMC memory widths must be input=256, weight=256, output=256");
  end
  // synthesis translate_on
endmodule
