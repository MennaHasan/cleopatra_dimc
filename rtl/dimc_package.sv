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
  localparam int DIMC_REG_WEIGHT_COLS = 4; // packed bytes per weight row
  localparam int DIMC_REG_INPUT_ROWS = 5; // packed bytes per input vector
  localparam int DIMC_REG_INPUT_COLS = 6;
  localparam int DIMC_REG_FORMAT = 7; // [1:0]: 1/2/4/8-bit mode; [3:2]: signing, 8-bit only
  localparam int DIMC_REG_BIAS = 8;
  localparam int DIMC_REG_COMPUTE_MASK = 9;
  localparam int DIMC_REG_WRITE_MASK = 10; // eight 32-bit words, low word first
  localparam int DIMC_NB_REGS = 18;

  // Memory holds packed input vectors ([q][l] tiles), packed row-major
  // weights, and row-major little-endian 32-bit results.
  
  // weight_rows/input_cols count scalar rows/columns. weight_cols/input_rows
  // count PACKED BYTES, equal to L*128 for all precisions. Scalar inner size
  // is packed_bytes * (8 >> mode). mode=00/01/10/11 selects 1/2/4/8 bits.
  // Operands within a byte occupy consecutive precision-bit fields.
  typedef struct packed {
    logic [31:0] input_addr, kernel_addr, output_addr;
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
