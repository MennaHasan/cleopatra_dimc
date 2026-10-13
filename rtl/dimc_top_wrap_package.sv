/* HCI sizes and req/rsp struct types for the flat-port dimc_top_wrap.
 * Sizes are fixed here because struct types used on module ports must live
 * at package scope; they match the widths asserted by dimc_top.
 */
`include "hci_helpers.svh"

package dimc_top_wrap_package;
  import hci_package::*;

  localparam hci_size_parameter_t `HCI_SIZE_PARAM(input_tcdm)  = '{DW:64,  AW:32, BW:8, UW:1, IW:1, EW:0, EHW:0};
  localparam hci_size_parameter_t `HCI_SIZE_PARAM(kernel_tcdm) = '{DW:256, AW:32, BW:8, UW:1, IW:1, EW:0, EHW:0};
  localparam hci_size_parameter_t `HCI_SIZE_PARAM(output_tcdm) = '{DW:256, AW:32, BW:8, UW:1, IW:1, EW:0, EHW:0};

  // Non-data fields are shared by the three sizes (checked in dimc_top_wrap)
  typedef logic [`HCI_SIZE_GET_AW(input_tcdm)-1:0]         dimc_addr_t;
  typedef logic [iomsb(`HCI_SIZE_GET_UW(input_tcdm)):0]    dimc_user_t;
  typedef logic [iomsb(`HCI_SIZE_GET_IW(input_tcdm)):0]    dimc_id_t;
  typedef logic [iomsb(`HCI_SIZE_GET_EW(input_tcdm)):0]    dimc_ecc_t;
  typedef logic [iomsb(`HCI_SIZE_GET_EHW(input_tcdm)):0]   dimc_ehw_t;

  typedef logic [`HCI_SIZE_GET_DW(input_tcdm)-1:0]                              dimc_input_data_t;
  typedef logic [`HCI_SIZE_GET_DW(input_tcdm)/`HCI_SIZE_GET_BW(input_tcdm)-1:0]   dimc_input_strb_t;
  typedef logic [`HCI_SIZE_GET_DW(kernel_tcdm)-1:0]                             dimc_kernel_data_t;
  typedef logic [`HCI_SIZE_GET_DW(kernel_tcdm)/`HCI_SIZE_GET_BW(kernel_tcdm)-1:0] dimc_kernel_strb_t;
  typedef logic [`HCI_SIZE_GET_DW(output_tcdm)-1:0]                             dimc_output_data_t;
  typedef logic [`HCI_SIZE_GET_DW(output_tcdm)/`HCI_SIZE_GET_BW(output_tcdm)-1:0] dimc_output_strb_t;

  `HCI_TYPEDEF_REQ_T(dimc_input_req_t,  dimc_addr_t, dimc_input_data_t,  dimc_input_strb_t,  dimc_user_t, dimc_id_t, dimc_ecc_t, dimc_ehw_t)
  `HCI_TYPEDEF_RSP_T(dimc_input_rsp_t,  dimc_input_data_t,  dimc_user_t, dimc_id_t, dimc_ecc_t, dimc_ehw_t)
  `HCI_TYPEDEF_REQ_T(dimc_kernel_req_t, dimc_addr_t, dimc_kernel_data_t, dimc_kernel_strb_t, dimc_user_t, dimc_id_t, dimc_ecc_t, dimc_ehw_t)
  `HCI_TYPEDEF_RSP_T(dimc_kernel_rsp_t, dimc_kernel_data_t, dimc_user_t, dimc_id_t, dimc_ecc_t, dimc_ehw_t)
  `HCI_TYPEDEF_REQ_T(dimc_output_req_t, dimc_addr_t, dimc_output_data_t, dimc_output_strb_t, dimc_user_t, dimc_id_t, dimc_ecc_t, dimc_ehw_t)
  `HCI_TYPEDEF_RSP_T(dimc_output_rsp_t, dimc_output_data_t, dimc_user_t, dimc_id_t, dimc_ecc_t, dimc_ehw_t)
endpackage
