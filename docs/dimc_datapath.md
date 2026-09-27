# Datapath interface

`dimc_datapath` instantiates one Cleopatra (two DIMC macros and 256
accumulators). Matrix dimensions are runtime inputs; no full matrices are
stored in the datapath.

## Command and status

- Pulse `start_i` when `busy_o` is low. Dimensions and configuration are
  captured on that rising clock edge. Starts while busy are ignored.
- Dimensions count elements, not bytes or stream beats. Weights have
  `weight_rows_i` rows and `weight_cols_i` columns; inputs have `input_rows_i`
  rows and `input_cols_i` columns. The inner dimensions must match.
- This implementation requires nonzero dimensions, 8-bit elements
  (`mode_i = 2'b11`), weight rows divisible by 32, the inner dimension
  divisible by 128, and input columns divisible by 8. Invalid commands stay
  idle and report a simulation assertion error.
- `ready_o` goes high after setup and remains high for the active job.
  It indicates that the dimensions have been captured; each stream's own
  `ready` controls actual data acceptance.
- `busy_o` stays high through acceptance of the last output tile and the
  following accumulator clear. `done_o` pulses for one cycle when busy ends.
- `clear_i` aborts the job and resets Cleopatra, including FIFOs and pipeline
  state. The sender must restart tile delivery with a new command.
- Mode, signedness, bias, write mask and compute mask are latched for the job
  and applied to both macros. Bias follows Cleopatra's existing behavior:
  it is added to each partial dot product, including each inner tile.

## Incoming tile order

Define `K = weight_rows_i / 32`, `L = weight_cols_i / 128`, and
`Q = input_cols_i / 8`. For nested loops over `k`, then `q`, then `l`, send
weight tile `[k][l]` and input tile `[l][q]`. Reused tiles must be resent.

Each stream transfers 256 bits per accepted beat, with all bytes valid:

- Weight tile: 128 beats, row first (0..31), then section (0..3).
- Input tile: 32 beats, column first (0..7), then section (0..3).

Within a row/vector, the first section contains the first 32 elements, with
the first element in its most significant byte, matching Test 1's files.
The streams handshake independently. Hold `valid` and data until accepted;
the datapath may stall either stream. It accepts only the expected number
of beats for the current loading phase.

The input FIFO defaults to 32 sections and must be at least that deep.
Macro 0 is loaded initially. Thereafter the active macro computes eight
vectors while the other macro loads the next weight tile. The shared input
FIFO retains the current tile's remaining vectors ahead of the next tile.
The other macro loads its first vector only after the current macro has
loaded its last vector. Macro selection changes only after all 256 results
are consumed and the next tile is ready.

## Output tiles

After all `L` contributions to one output tile are accumulated,
`result_valid_o` is asserted. `result_o[row][col]` contains a 32-bit value
for full-matrix position `[result_k_o*32+row][result_q_o*8+col]`.
Internally this maps to `acc_o[col*32+row]`.

All 256 values and both coordinates remain stable while valid is high.
The receiver may serialize the tile, asserting `result_ready_i` when it
has accepted the entire tile. A rising edge with valid and ready high
accepts the tile; accumulators clear on the following rising edge. Result
data is meaningful only while valid is high. No further computation starts
until the previous output tile has been accepted and cleared.

## Verification

`tb_dimc_datapath` uses the double-buffering Test 1 stimuli and golden output.
It checks the full K=4, L=3, Q=2 job, smaller runtime dimensions without reset,
odd/even final macro selection, source stalls, output backpressure,
concurrent loading/computation, and abort/restart during an active pipeline.

The focused datapath test connects this interface directly. For the complete
controller/streamer integration and `make sim-top` memory-to-memory test, see
[the standalone integration guide](dimc_integration.md).
