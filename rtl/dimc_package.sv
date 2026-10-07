/* Standalone DIMC software configuration and control/streamer interface. */
package dimc_package;
  parameter int unsigned NB_KERNEL_ROWS = 32;
  // HWPE-Ctrl IO registers start at byte offset 0x20. Indices below are
  // relative to that region, not absolute byte addresses.
  localparam int DIMC_IO_BASE = 'h20;
  localparam int DIMC_REG_INPUT_ADDR = 0;
  localparam int DIMC_REG_KERNEL_ADDR = 1;
  localparam int DIMC_REG_OUTPUT_ADDR = 2;
  localparam int DIMC_REG_WEIGHT_ROWS = 3;
  localparam int DIMC_REG_WEIGHT_COLS = 4;
  localparam int DIMC_REG_INPUT_ROWS = 5;
  localparam int DIMC_REG_INPUT_COLS = 6;
  localparam int DIMC_REG_FORMAT = 7; // [1:0] mode, [3:2] sign_8b
  localparam int DIMC_REG_BIAS = 8;
  localparam int DIMC_REG_COMPUTE_MASK = 9;
  localparam int DIMC_REG_WRITE_MASK = 10; // eight 32-bit words, low word first
  // Module 1 retains the original address registers; module 2 is appended.
  localparam int DIMC_REG_INPUT_ADDR_2 = 18;
  localparam int DIMC_REG_KERNEL_ADDR_2 = 19;
  localparam int DIMC_REG_OUTPUT_ADDR_2 = 20;
  localparam int DIMC_NB_REGS = 21;

  // Memory holds row-major 8-bit operands and little-endian 32-bit results.
  typedef struct packed {
    logic [31:0] input_addr, kernel_addr, output_addr; // module 1
    logic [31:0] input_addr_2, kernel_addr_2, output_addr_2; // module 2
    logic [31:0] weight_rows, weight_cols, input_rows, input_cols;
    logic [1:0] mode, sign_8b;
    logic [31:0] bias;
    logic [9:0] compute_mask;
    logic [255:0] write_mask;
  } dimc_config_t;

  typedef struct packed {
    logic busy;
    logic done;
  } dimc_streamer_flags_t;
endpackage
