/* Flat-port wrapper of dimc_top, used as synthesis top.
 * Interface ports at the top level get their default parameters during
 * elaboration (e.g. hwpe_ctrl_intf_periph ID_WIDTH=0), so the interfaces are
 * instantiated here with explicit sizes and exposed as plain signals:
 * HCI ports as req/rsp structs, the peripheral port as flat signals.
 */
`include "hci_helpers.svh"

module dimc_top_wrap
  import dimc_top_wrap_package::*;
  import hwpe_ctrl_package::*;
  import hci_package::*;
#(
  parameter int unsigned N_CORES = 2,
  parameter int unsigned N_CONTEXT = 2,
  parameter int unsigned ID_WIDTH = 10
)(
  input  logic clk_i, rst_ni,
  output logic busy_o,
  output logic [N_CORES-1:0][REGFILE_N_EVT-1:0] evt_o,
  // peripheral (configuration) port
  input  logic                periph_req_i,
  output logic                periph_gnt_o,
  input  logic [31:0]         periph_add_i,
  input  logic                periph_wen_i,
  input  logic [3:0]          periph_be_i,
  input  logic [31:0]         periph_data_i,
  input  logic [ID_WIDTH-1:0] periph_id_i,
  output logic [31:0]         periph_r_data_o,
  output logic                periph_r_valid_o,
  output logic [ID_WIDTH-1:0] periph_r_id_o,
  // HCI ports, module 1
  output dimc_input_req_t  input_tcdm_req_o,
  input  dimc_input_rsp_t  input_tcdm_rsp_i,
  output dimc_kernel_req_t kernel_tcdm_req_o,
  input  dimc_kernel_rsp_t kernel_tcdm_rsp_i,
  output dimc_output_req_t output_tcdm_req_o,
  input  dimc_output_rsp_t output_tcdm_rsp_i,
  // HCI ports, module 2
  output dimc_input_req_t  input_tcdm_2_req_o,
  input  dimc_input_rsp_t  input_tcdm_2_rsp_i,
  output dimc_kernel_req_t kernel_tcdm_2_req_o,
  input  dimc_kernel_rsp_t kernel_tcdm_2_rsp_i,
  output dimc_output_req_t output_tcdm_2_req_o,
  input  dimc_output_rsp_t output_tcdm_2_rsp_i
);
  localparam hci_size_parameter_t `HCI_SIZE_PARAM(input_tcdm_2)  = `HCI_SIZE_PARAM(input_tcdm);
  localparam hci_size_parameter_t `HCI_SIZE_PARAM(kernel_tcdm_2) = `HCI_SIZE_PARAM(kernel_tcdm);
  localparam hci_size_parameter_t `HCI_SIZE_PARAM(output_tcdm_2) = `HCI_SIZE_PARAM(output_tcdm);

  hwpe_ctrl_intf_periph #(.ID_WIDTH(ID_WIDTH)) periph (.clk(clk_i));
  `HCI_INTF(input_tcdm,    clk_i);
  `HCI_INTF(kernel_tcdm,   clk_i);
  `HCI_INTF(output_tcdm,   clk_i);
  `HCI_INTF(input_tcdm_2,  clk_i);
  `HCI_INTF(kernel_tcdm_2, clk_i);
  `HCI_INTF(output_tcdm_2, clk_i);

  assign periph.req      = periph_req_i;
  assign periph.add      = periph_add_i;
  assign periph.wen      = periph_wen_i;
  assign periph.be       = periph_be_i;
  assign periph.data     = periph_data_i;
  assign periph.id       = periph_id_i;
  assign periph_gnt_o     = periph.gnt;
  assign periph_r_data_o  = periph.r_data;
  assign periph_r_valid_o = periph.r_valid;
  assign periph_r_id_o    = periph.r_id;

  `HCI_ASSIGN_FROM_INTF(input_tcdm,    input_tcdm_req_o,    input_tcdm_rsp_i)
  `HCI_ASSIGN_FROM_INTF(kernel_tcdm,   kernel_tcdm_req_o,   kernel_tcdm_rsp_i)
  `HCI_ASSIGN_FROM_INTF(output_tcdm,   output_tcdm_req_o,   output_tcdm_rsp_i)
  `HCI_ASSIGN_FROM_INTF(input_tcdm_2,  input_tcdm_2_req_o,  input_tcdm_2_rsp_i)
  `HCI_ASSIGN_FROM_INTF(kernel_tcdm_2, kernel_tcdm_2_req_o, kernel_tcdm_2_rsp_i)
  `HCI_ASSIGN_FROM_INTF(output_tcdm_2, output_tcdm_2_req_o, output_tcdm_2_rsp_i)

  dimc_top #(
    .N_CORES(N_CORES), .N_CONTEXT(N_CONTEXT), .ID(ID_WIDTH),
    .INPUT_SIZE(`HCI_SIZE_PARAM(input_tcdm)),
    .KERNEL_SIZE(`HCI_SIZE_PARAM(kernel_tcdm)),
    .OUTPUT_SIZE(`HCI_SIZE_PARAM(output_tcdm))
  ) i_dimc_top (
    .clk_i, .rst_ni, .busy_o, .evt_o, .periph,
    .input_tcdm, .kernel_tcdm, .output_tcdm,
    .input_tcdm_2, .kernel_tcdm_2, .output_tcdm_2
  );

  // synthesis translate_off
  initial begin
    assert (ID_WIDTH >= 1)
      else $fatal(1, "ID_WIDTH must be at least 1");
    // the package shares non-data struct fields across the three sizes
    assert (`HCI_SIZE_GET_AW(kernel_tcdm) == `HCI_SIZE_GET_AW(input_tcdm) &&
            `HCI_SIZE_GET_AW(output_tcdm) == `HCI_SIZE_GET_AW(input_tcdm) &&
            `HCI_SIZE_GET_UW(kernel_tcdm) == `HCI_SIZE_GET_UW(input_tcdm) &&
            `HCI_SIZE_GET_UW(output_tcdm) == `HCI_SIZE_GET_UW(input_tcdm) &&
            `HCI_SIZE_GET_IW(kernel_tcdm) == `HCI_SIZE_GET_IW(input_tcdm) &&
            `HCI_SIZE_GET_IW(output_tcdm) == `HCI_SIZE_GET_IW(input_tcdm) &&
            `HCI_SIZE_GET_EW(kernel_tcdm) == `HCI_SIZE_GET_EW(input_tcdm) &&
            `HCI_SIZE_GET_EW(output_tcdm) == `HCI_SIZE_GET_EW(input_tcdm) &&
            `HCI_SIZE_GET_EHW(kernel_tcdm) == `HCI_SIZE_GET_EHW(input_tcdm) &&
            `HCI_SIZE_GET_EHW(output_tcdm) == `HCI_SIZE_GET_EHW(input_tcdm))
      else $fatal(1, "HCI sizes must share AW/UW/IW/EW/EHW");
  end
  // synthesis translate_on
endmodule
