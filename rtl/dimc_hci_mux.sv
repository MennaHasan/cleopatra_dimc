// Arbitration for weights-first read bursts and concurrent result writes.
// All outstanding reads belong to one source; retain its identity until drained.
// Writes may proceed while reads are outstanding. A stalled request owns
// the request bus until granted; round-robin priority advances only on grants.
module dimc_hci_mux (
  input logic clk_i, rst_ni,
  hci_core_intf.target input_port, weight_port, output_port,
  hci_core_intf.initiator memory
);
  logic [2:0] requests;
  logic [1:0] selected, locked_owner_q, priority_q;
  localparam int READ_DEPTH = 32;
  logic locked_q, pending_q, read_owner_q;
  logic [5:0] outstanding_q;
  logic read_push, read_pop;
  assign pending_q = outstanding_q != 0;
  assign read_push = memory.req && memory.gnt && memory.wen;
  assign read_pop = memory.r_valid && memory.r_ready;
  logic [2:0][31:0] addresses;
  logic [2:0][255:0] data;
  logic [2:0][31:0] enables;
  logic [2:0] directions, ids, users, response_ready;
  assign requests[0] = input_port.req && (outstanding_q < READ_DEPTH) && (!pending_q || !read_owner_q);
  assign addresses[0] = input_port.add;
  assign data[0] = input_port.data;
  assign enables[0] = input_port.be;
  assign directions[0] = input_port.wen;
  assign ids[0] = input_port.id;
  assign users[0] = input_port.user;
  assign response_ready[0] = input_port.r_ready;
  assign input_port.gnt = memory.gnt && memory.req && selected == 0;
  assign input_port.r_valid = memory.r_valid && pending_q && read_owner_q == 0;
  assign input_port.r_data = memory.r_data;
  assign input_port.r_id = memory.r_id;
  assign input_port.r_user = memory.r_user;
  assign input_port.r_opc = memory.r_opc;
  assign input_port.r_ecc = memory.r_ecc;
  assign input_port.egnt = '0;
  assign input_port.r_evalid = '0;
  assign requests[1] = weight_port.req && (outstanding_q < READ_DEPTH) && (!pending_q || read_owner_q);
  assign addresses[1] = weight_port.add;
  assign data[1] = weight_port.data;
  assign enables[1] = weight_port.be;
  assign directions[1] = weight_port.wen;
  assign ids[1] = weight_port.id;
  assign users[1] = weight_port.user;
  assign response_ready[1] = weight_port.r_ready;
  assign weight_port.gnt = memory.gnt && memory.req && selected == 1;
  assign weight_port.r_valid = memory.r_valid && pending_q && read_owner_q == 1;
  assign weight_port.r_data = memory.r_data;
  assign weight_port.r_id = memory.r_id;
  assign weight_port.r_user = memory.r_user;
  assign weight_port.r_opc = memory.r_opc;
  assign weight_port.r_ecc = memory.r_ecc;
  assign weight_port.egnt = '0;
  assign weight_port.r_evalid = '0;
  assign requests[2] = output_port.req;
  assign addresses[2] = output_port.add;
  assign data[2] = output_port.data;
  assign enables[2] = output_port.be;
  assign directions[2] = output_port.wen;
  assign ids[2] = output_port.id;
  assign users[2] = output_port.user;
  assign response_ready[2] = output_port.r_ready;
  assign output_port.gnt = memory.gnt && memory.req && selected == 2;
  assign output_port.r_valid = 1'b0;
  assign output_port.r_data = memory.r_data;
  assign output_port.r_id = memory.r_id;
  assign output_port.r_user = memory.r_user;
  assign output_port.r_opc = memory.r_opc;
  assign output_port.r_ecc = memory.r_ecc;
  assign output_port.egnt = '0;
  assign output_port.r_evalid = '0;
  always_comb begin
    selected = priority_q;
    case (priority_q)
      0: if (requests[0]) selected=0; else if (requests[1]) selected=1; else selected=2;
      1: if (requests[1]) selected=1; else if (requests[2]) selected=2; else selected=0;
      default: if (requests[2]) selected=2; else if (requests[0]) selected=0; else selected=1;
    endcase
    if (locked_q) selected = locked_owner_q;
  end
  assign memory.req = requests[selected];
  assign memory.add = addresses[selected];
  assign memory.data = data[selected];
  assign memory.be = enables[selected];
  assign memory.wen = directions[selected];
  assign memory.id = ids[selected];
  assign memory.user = users[selected];
  assign memory.ecc = '0;
  assign memory.ereq = '0;
  assign memory.r_eready = '0;
  assign memory.r_ready = pending_q && response_ready[read_owner_q];
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      locked_q <= 0; locked_owner_q <= 0; priority_q <= 0;
      outstanding_q <= 0; read_owner_q <= 0;
    end else begin
      if (memory.req) begin
        if (!memory.gnt) begin locked_q <= 1; locked_owner_q <= selected; end
        else begin
          locked_q <= 0;
          priority_q <= selected == 2 ? 0 : selected+1'b1;

        end
      end
      if (read_push && !pending_q) read_owner_q <= selected[0];
      case ({read_push,read_pop})
        2'b10: outstanding_q <= outstanding_q+1'b1;
        2'b01: outstanding_q <= outstanding_q-1'b1;
        default: ;
      endcase
    end
  end
  // synthesis translate_off
  always @(posedge clk_i) if (rst_ni) begin
    assert (outstanding_q <= READ_DEPTH)
      else $fatal(1, "Too many outstanding shared-port reads");
    assert (!memory.r_valid || pending_q)
      else $fatal(1, "Unowned memory response");
  end
  // synthesis translate_on
endmodule
