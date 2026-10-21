/* HCI size and req/rsp struct types for the flat-port dimc_top_wrap.
 * Both modules expose the same 256-bit memory interface.
 * Port struct types are defined at package scope.
 */
`include "hci_helpers.svh"

package dimc_top_wrap_package;
  import hci_package::*;

  localparam hci_size_parameter_t `HCI_SIZE_PARAM(tcdm) = '{DW:256, AW:32, BW:8, UW:1, IW:1, EW:0, EHW:0};

  typedef logic [`HCI_SIZE_GET_AW(tcdm)-1:0]                   dimc_addr_t;
  typedef logic [iomsb(`HCI_SIZE_GET_UW(tcdm)):0]              dimc_user_t;
  typedef logic [iomsb(`HCI_SIZE_GET_IW(tcdm)):0]              dimc_id_t;
  typedef logic [iomsb(`HCI_SIZE_GET_EW(tcdm)):0]              dimc_ecc_t;
  typedef logic [iomsb(`HCI_SIZE_GET_EHW(tcdm)):0]             dimc_ehw_t;
  
  typedef logic [`HCI_SIZE_GET_DW(tcdm)-1:0]                  dimc_data_t;
  typedef logic [`HCI_SIZE_GET_DW(tcdm)/`HCI_SIZE_GET_BW(tcdm)-1:0] dimc_strb_t;

  `HCI_TYPEDEF_REQ_T(dimc_req_t, dimc_addr_t, dimc_data_t, dimc_strb_t, dimc_user_t, dimc_id_t, dimc_ecc_t, dimc_ehw_t)
  `HCI_TYPEDEF_RSP_T(dimc_rsp_t, dimc_data_t, dimc_user_t, dimc_id_t, dimc_ecc_t, dimc_ehw_t)
endpackage
