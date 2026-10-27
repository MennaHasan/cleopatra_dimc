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
  // One shared 256-bit read/write memory interface.
  output dimc_req_t tcdm_req_o,
  input  dimc_rsp_t tcdm_rsp_i
);
  hwpe_ctrl_intf_periph #(.ID_WIDTH(ID_WIDTH)) periph (.clk(clk_i));
  `HCI_INTF(tcdm, clk_i);

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

  `HCI_ASSIGN_FROM_INTF(tcdm, tcdm_req_o, tcdm_rsp_i)

  dimc_top #(
    .N_CORES(N_CORES), .N_CONTEXT(N_CONTEXT), .ID(ID_WIDTH),
    .INPUT_SIZE(`HCI_SIZE_PARAM(tcdm)),
    .KERNEL_SIZE(`HCI_SIZE_PARAM(tcdm)),
    .OUTPUT_SIZE(`HCI_SIZE_PARAM(tcdm))
  ) i_dimc_top (
    .clk_i, .rst_ni, .busy_o, .evt_o, .periph,
    .tcdm
  );

  // synthesis translate_off
  initial begin
    assert (ID_WIDTH >= 1)
      else $fatal(1, "ID_WIDTH must be at least 1");
  end
  // synthesis translate_on
endmodule
