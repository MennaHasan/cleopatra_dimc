/* Packed input vectors and row-major weights/results <-> Cleopatra tiles.
 * Each input tile is 1024 bytes: eight vectors, four 256-bit sections each.
 * Input tiles are stored in [q][l] order and reused for every weight group k.
 * HCI sources deliver input/weight sections directly; no transpose storage.
 * Read bursts alternate: weights for a tile, then that tile's inputs.
 * Internal input/weight/output channels share one external 256-bit HCI port.
 */
module dimc_streamer
  import dimc_package::*;
  import hci_package::*;
#(
  parameter hci_size_parameter_t INPUT_SIZE = '{DW:256, AW:32, BW:8, UW:1, IW:1, EW:0, EHW:0},
  parameter hci_size_parameter_t KERNEL_SIZE = '{DW:256, AW:32, BW:8, UW:1, IW:1, EW:0, EHW:0},
  parameter hci_size_parameter_t OUTPUT_SIZE = '{DW:256, AW:32, BW:8, UW:1, IW:1, EW:0, EHW:0}
)(
  input logic clk_i, rst_ni, clear_i, abort_i, start_i,
  input wire dimc_config_t config_i,
  output dimc_streamer_flags_t flags_o,
  hci_core_intf.initiator input_tcdm,
  hci_core_intf.initiator kernel_tcdm,
  hci_core_intf.initiator output_tcdm,
  hwpe_stream_intf_stream.source input_o,
  hwpe_stream_intf_stream.source kernel_o,
  input wire [31:0] result_i [0:31][0:7],
  input logic result_valid_i,
  output logic result_ready_o
);
  hci_streamer_ctrl_t input_ctrl, kernel_ctrl, output_ctrl;
  hci_streamer_flags_t input_flags, kernel_flags, output_flags;
  hwpe_stream_intf_stream #(.DATA_WIDTH(256)) input_mem (.clk(clk_i));
  hwpe_stream_intf_stream #(.DATA_WIDTH(256)) kernel_mem (.clk(clk_i));
  hwpe_stream_intf_stream #(.DATA_WIDTH(256)) output_mem (.clk(clk_i));
  typedef enum logic [1:0] {O_IDLE,O_SEND,O_WAIT,O_ACK} output_state_t;
  output_state_t output_q;
  typedef enum logic [2:0] {
    R_IDLE, R_WEIGHT_START, R_WEIGHT_WAIT, R_INPUT_START, R_INPUT_WAIT, R_DONE
  } read_state_t;
  read_state_t read_q;
  dimc_config_t cfg_q;
  logic busy_q, aborting_q, aborting, output_finished_q;
  logic [31:0] k_q, l_q, q_q;
  logic [31:0] weight_base_q, weight_group_q, input_base_q;
  logic [31:0] output_base_q, output_group_q, out_k_q, out_q_q;
  logic [4:0] output_row_q;
  logic last_pair, last_output, engines_idle;
  assign aborting=abort_i || aborting_q;
  assign busy_q=read_q!=R_IDLE;
  assign last_pair=k_q==(cfg_q.weight_rows>>5)-1 &&
                   l_q==(cfg_q.weight_cols>>7)-1 && q_q==(cfg_q.input_cols>>3)-1;
  assign last_output=out_k_q==(cfg_q.weight_rows>>5)-1 && out_q_q==(cfg_q.input_cols>>3)-1;
  assign engines_idle=input_flags.ready_start && kernel_flags.ready_start && output_flags.ready_start && output_q==O_IDLE;
  assign flags_o.busy=aborting ? !engines_idle : busy_q;
  always_comb begin
    input_ctrl='0; kernel_ctrl='0; output_ctrl='0;
    input_ctrl.req_start=read_q==R_INPUT_START && input_flags.ready_start && !aborting;
    input_ctrl.addressgen_ctrl.base_addr=input_base_q;
    input_ctrl.addressgen_ctrl.tot_len=32;
    input_ctrl.addressgen_ctrl.d0_len=32;
    input_ctrl.addressgen_ctrl.d0_stride=32;
    kernel_ctrl.req_start=read_q==R_WEIGHT_START && kernel_flags.ready_start && !aborting;
    kernel_ctrl.addressgen_ctrl.base_addr=weight_base_q;
    kernel_ctrl.addressgen_ctrl.tot_len=128;
    kernel_ctrl.addressgen_ctrl.d0_len=4;
    kernel_ctrl.addressgen_ctrl.d0_stride=32;
    kernel_ctrl.addressgen_ctrl.d1_len=32;
    kernel_ctrl.addressgen_ctrl.d1_stride=cfg_q.weight_cols;
    kernel_ctrl.addressgen_ctrl.dim_enable_1h=4'b0001;
    output_ctrl.req_start=busy_q && output_q==O_IDLE && result_valid_i && output_flags.ready_start && !aborting;
    output_ctrl.addressgen_ctrl.base_addr=output_base_q;
    output_ctrl.addressgen_ctrl.tot_len=32;
    output_ctrl.addressgen_ctrl.d0_len=32;
    output_ctrl.addressgen_ctrl.d0_stride=cfg_q.input_cols<<2;
  end
  hci_core_source #(
    .MISALIGNED_ACCESSES(0), .DIM_ENABLE_1H(4'b0000), .HCI_SIZE_tcdm(INPUT_SIZE)
  ) i_input_source (
    .clk_i, .rst_ni, .test_mode_i(1'b0), .clear_i, .enable_i(1'b1),
    .tcdm(input_tcdm), .stream(input_mem), .ctrl_i(input_ctrl), .flags_o(input_flags)
  );
  hci_core_source #(.MISALIGNED_ACCESSES(0),.DIM_ENABLE_1H(4'b0001),.HCI_SIZE_tcdm(KERNEL_SIZE)) i_kernel_source (
    .clk_i,.rst_ni,.test_mode_i(1'b0),.clear_i,.enable_i(1'b1),
    .tcdm(kernel_tcdm),.stream(kernel_mem),.ctrl_i(kernel_ctrl),.flags_o(kernel_flags)
  );
  hci_core_sink #(.MISALIGNED_ACCESSES(0),.TCDM_FIFO_DEPTH(0),.DIM_ENABLE_1H(4'b0000),.HCI_SIZE_tcdm(OUTPUT_SIZE)) i_output_sink (
    .clk_i,.rst_ni,.test_mode_i(1'b0),.clear_i,.enable_i(1'b1),
    .tcdm(output_tcdm),.stream(output_mem),.ctrl_i(output_ctrl),.flags_o(output_flags)
  );
  for(genvar b=0;b<32;b++) begin : gen_bytes
    assign kernel_o.data[255-b*8 -:8]=kernel_mem.data[b*8 +:8];
    assign input_o.data[255-b*8 -:8]=input_mem.data[b*8 +:8];
  end
  assign kernel_o.valid=kernel_mem.valid && !aborting && !clear_i;
  assign kernel_o.strb='1;
  assign kernel_mem.ready=aborting || kernel_o.ready;
  assign input_mem.ready=aborting || input_o.ready;
  assign input_o.valid=input_mem.valid && !aborting && !clear_i;
  assign input_o.strb='1;
  for(genvar c=0;c<8;c++) begin : gen_output
    assign output_mem.data[c*32 +:32]=result_i[output_row_q][c];
  end
  assign output_mem.valid=output_q==O_SEND;
  assign output_mem.strb='1;
  assign result_ready_o=output_q==O_ACK;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if(!rst_ni) begin
      read_q<=R_IDLE; aborting_q<=0; flags_o.done<=0; cfg_q<='0; output_q<=O_IDLE;
      output_row_q<=0;
      output_finished_q<=0;
      k_q<=0; l_q<=0; q_q<=0;
      weight_base_q<=0;weight_group_q<=0;input_base_q<=0;
      output_base_q<=0;output_group_q<=0;out_k_q<=0;out_q_q<=0;
    end else if(clear_i) begin
      read_q<=R_IDLE; aborting_q<=0; flags_o.done<=0; output_q<=O_IDLE;
    end else begin
      flags_o.done<=0;
      if(abort_i) aborting_q<=1;
      if(!aborting) begin
        case(read_q)
          R_IDLE: if(start_i) begin
            cfg_q<=config_i;
            k_q<=0; l_q<=0; q_q<=0;
            weight_base_q<=config_i.kernel_addr;
            weight_group_q<=config_i.kernel_addr;
            input_base_q<=config_i.input_addr;
            output_base_q<=config_i.output_addr;
            output_group_q<=config_i.output_addr;
            out_k_q<=0; out_q_q<=0; output_finished_q<=0;
            read_q<=R_WEIGHT_START;
          end
          R_WEIGHT_START: if(kernel_ctrl.req_start) read_q<=R_WEIGHT_WAIT;
          R_WEIGHT_WAIT: if(kernel_flags.done) read_q<=R_INPUT_START;
          R_INPUT_START: if(input_ctrl.req_start) read_q<=R_INPUT_WAIT;
          R_INPUT_WAIT: if(input_flags.done) begin
            if(last_pair) read_q<=R_DONE;
            else begin
              // One shared tile index advances only after both read bursts.
              if(l_q!=(cfg_q.weight_cols>>7)-1) begin
                l_q<=l_q+1;
                weight_base_q<=weight_base_q+128;
                input_base_q<=input_base_q+1024;
              end else begin
                l_q<=0;
                if(q_q!=(cfg_q.input_cols>>3)-1) begin
                  q_q<=q_q+1;
                  weight_base_q<=weight_group_q;
                  input_base_q<=input_base_q+1024;
                end else begin
                  q_q<=0; k_q<=k_q+1;
                  weight_group_q<=weight_group_q+(cfg_q.weight_cols<<5);
                  weight_base_q<=weight_group_q+(cfg_q.weight_cols<<5);
                  input_base_q<=cfg_q.input_addr;
                end
              end
              read_q<=R_WEIGHT_START;
            end
          end
          R_DONE: if(output_finished_q && output_q==O_IDLE) begin
            read_q<=R_IDLE;
            flags_o.done<=1;
          end
          default: read_q<=R_IDLE;
        endcase
      end
      // Finish an already-started write burst even during abort.
      case(output_q)
        O_IDLE:if(output_ctrl.req_start) begin output_row_q<=0;output_q<=O_SEND;end
        O_SEND:if(output_mem.valid && output_mem.ready) begin output_row_q<=output_row_q+1'b1;if(output_row_q==31)output_q<=O_WAIT;end
        O_WAIT:if(output_flags.done)output_q<=O_ACK;
        O_ACK:begin
          output_q<=O_IDLE;
          if(last_output)output_finished_q<=1;
          else if(out_q_q!=(cfg_q.input_cols>>3)-1)begin out_q_q<=out_q_q+1;output_base_q<=output_base_q+32;end
          else begin out_q_q<=0;out_k_q<=out_k_q+1;output_group_q<=output_group_q+(cfg_q.input_cols<<7);output_base_q<=output_group_q+(cfg_q.input_cols<<7);end
        end
        default:output_q<=O_IDLE;
      endcase
    end
  end
endmodule
