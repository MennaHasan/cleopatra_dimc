/* One complete module: two macros, 256 accumulators, three FIFOs and
 * dedicated input/weight/output streamers. Instances advance independently.
 * MODULE_ID=1 maps local m0/m1 to macros 1/2; MODULE_ID=2 maps them to 3/4.
 */
module dimc_module
  import dimc_package::*;
  import hci_package::*;
#(
  parameter int MODULE_ID = 1,
  parameter hci_size_parameter_t INPUT_SIZE = '{DW:64, AW:32, BW:8, UW:1, IW:1, EW:0, EHW:0},
  parameter hci_size_parameter_t KERNEL_SIZE = '{DW:256, AW:32, BW:8, UW:1, IW:1, EW:0, EHW:0},
  parameter hci_size_parameter_t OUTPUT_SIZE = '{DW:256, AW:32, BW:8, UW:1, IW:1, EW:0, EHW:0}
)(
  input logic clk_i, rst_ni, clear_i, abort_i, datapath_start_i, streamer_start_i,
  input wire dimc_config_t config_i,
  output logic datapath_ready_o, datapath_done_o,
  output dimc_streamer_flags_t streamer_flags_o,
  hci_core_intf.initiator input_tcdm,
  hci_core_intf.initiator kernel_tcdm,
  hci_core_intf.initiator output_tcdm
);
  dimc_config_t config_;
  // Both modules receive the identical bundle; select only local addresses.
  always_comb begin
    config_ = config_i;
    if (MODULE_ID == 2) begin
      config_.input_addr = config_i.input_addr_2;
      config_.kernel_addr = config_i.kernel_addr_2;
      config_.output_addr = config_i.output_addr_2;
    end
  end
  logic result_valid, result_ready;
  logic [31:0] result [0:31][0:7];
  hwpe_stream_intf_stream #(.DATA_WIDTH(256)) input_stream (.clk(clk_i));
  hwpe_stream_intf_stream #(.DATA_WIDTH(256)) kernel_stream (.clk(clk_i));
  dimc_datapath i_datapath (
    .clk_i, .rst_ni, .clear_i, .start_i(datapath_start_i),
    .weight_rows_i(config_.weight_rows), .weight_cols_i(config_.weight_cols),
    .input_rows_i(config_.input_rows), .input_cols_i(config_.input_cols),
    .mode_i(config_.mode), .sign_8b_i(config_.sign_8b), .bias_i(config_.bias),
    .write_mask_i(config_.write_mask), .compute_mask_i(config_.compute_mask),
    .input_i(input_stream), .kernel_i(kernel_stream),
    .ready_o(datapath_ready_o), .done_o(datapath_done_o), .result_o(result),
    .result_valid_o(result_valid), .result_ready_i(result_ready)
  );
  dimc_streamer #(.INPUT_SIZE(INPUT_SIZE), .KERNEL_SIZE(KERNEL_SIZE), .OUTPUT_SIZE(OUTPUT_SIZE))
  i_streamer (
    .clk_i, .rst_ni, .clear_i, .abort_i, .start_i(streamer_start_i),
    .config_i(config_), .flags_o(streamer_flags_o), .input_tcdm, .kernel_tcdm, .output_tcdm,
    .input_o(input_stream), .kernel_o(kernel_stream),
    .result_i(result), .result_valid_i(result_valid), .result_ready_o(result_ready)
  );
endmodule
