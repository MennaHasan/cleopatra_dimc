// Behavioral byte memory shared by the six HCI ports in tb_dimc_top.
// This drives memory responses; it does not monitor accelerator internals.
`timescale 1ns/1ps
package tb_dimc_memory;
  byte unsigned mem [0:262143];
endpackage

// Simulation-only shared memory port. Requests can queue, grants can stall,
// responses are ordered and delayed, and remain stable under backpressure.
// Stores commit at the grant edge (the HCI sink's completion contract).
module tb_dimc_memory_port #(
  parameter int DW=256, SALT=0,
  parameter bit WRITE_PORT=0
)(
  input logic clk_i, rst_ni, stalls_i, hold_i,
  input int response_delay_i,
  input logic [31:0] region_base_i, region_bytes_i,
  hci_core_intf.target port,
  output int transfers_o
);
  import tb_dimc_memory::*;
  typedef struct packed {logic [DW-1:0] data; logic id; int due;} response_t;
  response_t queue_ [0:7];
  int read_ptr=0, write_ptr=0, queued=0;
  response_t entry;
  int cycle=0;
  logic [DW-1:0] saved_data;
  logic [31:0] saved_addr;
  logic [DW/8-1:0] saved_be;
  logic saved_wen;
  logic accepted, consumed;
  // Change grant policy after the edge, like cycle/queue updates below. HCI's
  // delayed assertion clock then observes the grant before the acceptance edge.
  logic hold_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) hold_q <= 0;
    else hold_q <= hold_i;
  end
  assign port.gnt = rst_ni && port.req && !hold_q && queued<8 &&
                    (!stalls_i || (cycle+SALT)%5 != 0);
  assign port.r_valid = rst_ni && queued>0 && queue_[read_ptr].due <= cycle;
  assign port.r_data = queued>0 ? queue_[read_ptr].data : '0;
  assign port.r_id = queued>0 ? queue_[read_ptr].id : '0;
  assign port.r_user='0;
  assign port.r_opc=0;
  assign port.r_ecc='0;
  assign port.egnt='0;
  assign port.r_evalid='0;
  always @(posedge clk_i) begin
    if (!rst_ni) begin
      read_ptr=0; write_ptr=0; queued=0; cycle=0; transfers_o=0;
    end else begin
      saved_addr=port.add; saved_data=port.data; saved_be=port.be; saved_wen=port.wen;
      accepted = port.req && port.gnt;
      consumed = port.r_valid && port.r_ready;
      // All clocked DUT blocks sample first. Then update this simulation model
      // in the inactive region, before the interface's delayed assertions.
      // saved_* holds the request that was actually accepted at the edge.
      #0;
      if (consumed) begin
        read_ptr=(read_ptr+1)%8; queued--;
      end
      if (accepted) begin
        assert (saved_addr >= region_base_i &&
                64'(saved_addr)+DW/8 <= 64'(region_base_i)+region_bytes_i)
          else $fatal(1, "Memory access outside matrix: address=%h base=%h bytes=%0d", saved_addr, region_base_i, region_bytes_i);
        assert (saved_wen == !WRITE_PORT) else $fatal(1, "Wrong memory direction");
        transfers_o++;
        if (saved_wen) begin
          for (int b=0;b<DW/8;b++) entry.data[b*8 +: 8]=mem[saved_addr+b];
          entry.id=port.id;
          entry.due=cycle+response_delay_i;
          queue_[write_ptr]=entry;
          write_ptr=(write_ptr+1)%8; queued++;
        end else begin
          assert (&saved_be) else $fatal(1, "Unexpected partial result write");
          for (int b=0;b<DW/8;b++) if (saved_be[b]) mem[saved_addr+b]=saved_data[b*8 +: 8];
        end
      end
      cycle <= cycle+1;
    end
  end
endmodule

