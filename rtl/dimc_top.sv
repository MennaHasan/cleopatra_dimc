/* One software-controlled DIMC macro with streamed tile data. */
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
  parameter hci_size_parameter_t OUTPUT_SIZE = '{DW:256, AW:32, BW:8, UW:1, IW:1, EW:0, EHW:0},
  parameter int unsigned INP_FIFO_DEPTH = 32,
  parameter int unsigned WGT_FIFO_DEPTH = 128,
  parameter int unsigned OUT_FIFO_DEPTH = 64
)(
  input logic clk_i, rst_ni,
  output logic busy_o,
  output logic [N_CORES-1:0][REGFILE_N_EVT-1:0] evt_o,
  hwpe_ctrl_intf_periph.slave periph,
  hci_core_intf.initiator tcdm
);
  dimc_config_t config_;
  dimc_streamer_flags_t streamer_flags;
  logic streamer_start, clear, abort_job;
  logic result_valid, result_ready;
  logic macro_compe, macro_fcsn, macro_rcsn, macro_wcsn, macro_wen;
  logic [1:0] macro_mode, macro_fa, macro_sign_8b;
  logic [31:0] macro_addin, macro_psout;
  logic [6:0] macro_ra, macro_wa;
  logic [3:0] macro_rcsn_sections;
  logic [255:0] macro_mask;
  logic [9:0] macro_compute_mask;
  logic macro_readyn, accumulator_clear, result_capture;
  logic macro_rst_n;
  logic [255:0] acc_sel;
  logic [31:0] accumulators [0:255];
  logic [31:0] result [0:31][0:7];

  hwpe_stream_intf_stream #(.DATA_WIDTH(256)) input_stream (.clk(clk_i));
  hwpe_stream_intf_stream #(.DATA_WIDTH(256)) kernel_stream (.clk(clk_i));
  hci_core_intf #(.DW(256), .IW(1), .EW(0), .EHW(0)) input_tcdm (.clk(clk_i));
  hci_core_intf #(.DW(256), .IW(1), .EW(0), .EHW(0)) kernel_tcdm (.clk(clk_i));
  hci_core_intf #(.DW(256), .IW(1), .EW(0), .EHW(0)) output_tcdm (.clk(clk_i));

  logic inp_full, inp_empty, wgt_full, wgt_empty, out_full, out_empty;
  logic inp_push, inp_pop, wgt_push, wgt_pop, out_push, out_pop;
  logic [255:0] inp_rdata, wgt_rdata;
  logic [31:0] out_rdata;

  assign inp_push = input_stream.valid && input_stream.ready;
  assign wgt_push = kernel_stream.valid && kernel_stream.ready;
  assign inp_pop = ~macro_fcsn && ~inp_empty;
  assign wgt_pop = ~macro_wcsn && ~macro_wen && ~wgt_empty;
  assign out_push = result_capture && ~out_full;
  assign out_pop = ~out_empty;

  fifo_v3 #(
    .FALL_THROUGH (1'b0),
    .DATA_WIDTH   (256),
    .DEPTH        (INP_FIFO_DEPTH)
  ) u_inp_fifo (
    .clk_i      (clk_i),
    .rst_ni     (macro_rst_n),
    .flush_i    (1'b0),
    .testmode_i (1'b0),
    .full_o     (inp_full),
    .empty_o    (inp_empty),
    .usage_o    (),
    .data_i     (input_stream.data),
    .push_i     (inp_push),
    .data_o     (inp_rdata),
    .pop_i      (inp_pop)
  );

  fifo_v3 #(
    .FALL_THROUGH (1'b0),
    .DATA_WIDTH   (256),
    .DEPTH        (WGT_FIFO_DEPTH)
  ) u_wgt_fifo (
    .clk_i      (clk_i),
    .rst_ni     (macro_rst_n),
    .flush_i    (1'b0),
    .testmode_i (1'b0),
    .full_o     (wgt_full),
    .empty_o    (wgt_empty),
    .usage_o    (),
    .data_i     (kernel_stream.data),
    .push_i     (wgt_push),
    .data_o     (wgt_rdata),
    .pop_i      (wgt_pop)
  );

  fifo_v3 #(
    .FALL_THROUGH (1'b0),
    .DATA_WIDTH   (32),
    .DEPTH        (OUT_FIFO_DEPTH)
  ) u_out_fifo (
    .clk_i      (clk_i),
    .rst_ni     (macro_rst_n),
    .flush_i    (1'b0),
    .testmode_i (1'b0),
    .full_o     (out_full),
    .empty_o    (out_empty),
    .usage_o    (),
    .data_i     (macro_psout),
    .push_i     (out_push),
    .data_o     (out_rdata),
    .pop_i      (out_pop)
  );

  dimc_hci_mux i_memory_mux (
    .clk_i, .rst_ni, .input_port(input_tcdm),
    .weight_port(kernel_tcdm), .output_port(output_tcdm), .memory(tcdm)
  );

  dimc_ctrl #(.N_CORES(N_CORES), .N_CONTEXT(N_CONTEXT), .ID(ID)) i_ctrl (
    .clk_i, .rst_ni, .periph, .evt_o, .config_o(config_),
    .streamer_start_o(streamer_start), .clear_o(clear), .abort_o(abort_job), .busy_o,
    .streamer_flags_i(streamer_flags), .input_i(input_stream), .kernel_i(kernel_stream),
    .inp_full_i(inp_full), .inp_empty_i(inp_empty),
    .wgt_full_i(wgt_full), .wgt_empty_i(wgt_empty),
    .macro_readyn_i(macro_readyn),
    .macro_compe_o(macro_compe), .macro_fcsn_o(macro_fcsn),
    .macro_mode_o(macro_mode), .macro_fa_o(macro_fa), .macro_addin_o(macro_addin),
    .macro_ra_o(macro_ra), .macro_wa_o(macro_wa), .macro_rcsn_o(macro_rcsn),
    .macro_rcsn_sections_o(macro_rcsn_sections), .macro_wcsn_o(macro_wcsn),
    .macro_wen_o(macro_wen), .macro_mask_o(macro_mask),
    .macro_compute_mask_o(macro_compute_mask), .macro_sign_8b_o(macro_sign_8b),
    .accumulator_clear_o(accumulator_clear), .result_capture_o(result_capture),
    .result_valid_o(result_valid), .result_ready_i(result_ready)
  );

  dimc_streamer #(
    .INPUT_SIZE(INPUT_SIZE), .KERNEL_SIZE(KERNEL_SIZE), .OUTPUT_SIZE(OUTPUT_SIZE)
  ) i_streamer (
    .clk_i, .rst_ni, .clear_i(clear), .abort_i(abort_job), .start_i(streamer_start),
    .config_i(config_), .flags_o(streamer_flags),
    .input_tcdm, .kernel_tcdm, .output_tcdm,
    .input_o(input_stream), .kernel_o(kernel_stream),
    .result_i(result), .result_valid_i(result_valid), .result_ready_o(result_ready)
  );

  assign macro_rst_n = rst_ni && !clear;
  spatz_dimc #(.SECTION_WIDTH(256)) i_macro (
    .RCK(clk_i), .RESETn(macro_rst_n), .COMPE(macro_compe), .READYN(macro_readyn),
    .FCSN(macro_fcsn), .MODE(macro_mode), .FA(macro_fa), .FD(inp_rdata),
    .ADDIN(macro_addin), .SOUT(), .PSOUT(macro_psout), .Q(), .D(wgt_rdata),
    .RA(macro_ra), .WA(macro_wa), .RCSN(macro_rcsn),
    .RCSN0(macro_rcsn_sections[0]), .RCSN1(macro_rcsn_sections[1]),
    .RCSN2(macro_rcsn_sections[2]), .RCSN3(macro_rcsn_sections[3]),
    .WCK(clk_i), .WCSN(macro_wcsn), .WEN(macro_wen), .M(macro_mask),
    .compute_mask(macro_compute_mask), .sign_8b(macro_sign_8b)
  );

  cleopatra_ctrl #(.WIDTH(256)) i_accumulator_ctrl (
    .clk(clk_i), .rst_n(rst_ni), .clear(accumulator_clear),
    .out_pop(out_pop), .acc_sel_o(acc_sel)
  );

  for (genvar i = 0; i < 256; i++) begin : gen_accumulators
    accumulator #(.DATA_WIDTH(32), .OUT_WIDTH(32)) i_accumulator (
      .clk_i, .rst_ni, .enable_i(out_pop && acc_sel[i]),
      .clear_i(accumulator_clear), .data_i(out_rdata), .acc_o(accumulators[i])
    );
  end

  for (genvar r = 0; r < 32; r++) begin : gen_result_rows
    for (genvar c = 0; c < 8; c++) begin : gen_result_cols
      assign result[r][c] = accumulators[c*32+r];
    end
  end

  // synthesis translate_off
  initial begin
    assert (INPUT_SIZE.DW == 256 && KERNEL_SIZE.DW == 256 && OUTPUT_SIZE.DW == 256)
      else $fatal(1, "DIMC memory widths must be input=256, weight=256, output=256");
  end
  // synthesis translate_on
endmodule
