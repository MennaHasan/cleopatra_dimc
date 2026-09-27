# Standalone DIMC integration

`dimc_top` connects the controller, streamers, and Cleopatra datapath. It uses
the repository's existing `hwpe-ctrl`, `hwpe-stream`, and `hci` dependencies.
MAGIA uses the same library family, but this accelerator is standalone and
does not replace any MAGIA component or depend on a MAGIA build.

## Responsibilities

- `dimc_ctrl`: software register interface (`hwpe_ctrl_slave`), validation,
  captured job configuration, start, completion event, and soft-clear drain.
- `dimc_streamer`: two `hci_core_source` instances and one `hci_core_sink`,
  tile addresses, byte ordering, input transpose storage, and output writes.
- `dimc_datapath`: double-buffered macro loading/computation, accumulation,
  and holding each completed output tile until accepted.

One job multiplies the complete matrices. For weights of shape `(K*32, L*128)`
and inputs of shape `(L*128, Q*8)`, it visits tile pairs in `[k][q][l]` order,
with `l` changing fastest. Reused tiles are fetched again from memory.

## Memory layout and ports

All ports use byte addresses in one 32-bit address space. Operands are dense,
row-major 8-bit values. Results are dense, row-major little-endian 32-bit values.
Memory byte lane 0 corresponds to the lowest address. No software tiling,
padding, or transpose is needed. Input and weight matrices must remain stable
during the job; the output region must not overlap either operand region.

| Top-level HCI port | Width | Transfer |
| --- | --- | --- |
| `input_tcdm` | 64 bits | Eight adjacent input columns from one matrix row |
| `kernel_tcdm` | 256 bits | One 32-byte weight section |
| `output_tcdm` | 256 bits | Eight 32-bit results from one output-tile row |

These are three independent interfaces, replacing the old uniform-width port
array. They may be connected to a shared memory system through suitable
arbitration/adapters. The exposed size structs carry interface metadata;
the three data widths above are fixed by the current packing logic.

The input source reads 128 groups of eight bytes with a stride equal to the
full input row length. A 1024-byte tile buffer then assembles column vectors
as 32 separate 256-bit stream beats. Only this one input tile is buffered in
the streamer. The weight source reads four 256-bit sections per row and uses
the full weight row length as its outer stride. Byte reversal maps memory's
little-endian lanes to Cleopatra's MSB-first section representation.

For outputs, one write stores a complete eight-element tile row. Subsequent
writes advance by the full result row length in bytes. `result_ready` is
asserted only after the HCI sink has completed all 32 writes, so the datapath
cannot clear its accumulator tile prematurely. There is no output FIFO between
the sink and external memory. An accepted HCI write grant must mean that the
memory system has accepted responsibility for the write; read responses use
HCI `r_valid/r_ready` and may be delayed or backpressured.

## Software registers

Use the standard HWPE-Ctrl peripheral interface: `wen=0` writes, `wen=1` reads,
and byte enables select written bytes. Register offsets below are byte offsets
relative to this accelerator's peripheral base.

| Offset | Register | Use |
| --- | --- | --- |
| `0x00` | Trigger | Write zero to commit configuration and trigger processing |
| `0x04` | Acquire | Read to acquire a free HWPE context; negative result means retry |
| `0x08` | Finished | Standard HWPE-Ctrl completion register |
| `0x0c` | Status | Standard HWPE-Ctrl context status |
| `0x10` | Running | Standard HWPE-Ctrl running-job register |
| `0x14` | Soft clear | Write zero to abort and clear register contexts |
| `0x18` | DIMC status extension | Bit 0: controller busy, bit 1: invalid configuration |
| `0x1c` | Software events | Standard HWPE-Ctrl software-event register |
| `0x20` | Input address | Input matrix base, aligned to 8 bytes |
| `0x24` | Weight address | Weight matrix base, aligned to 32 bytes |
| `0x28` | Output address | Result matrix base, aligned to 32 bytes |
| `0x2c` | Weight rows | Nonzero multiple of 32 |
| `0x30` | Weight columns | Nonzero multiple of 128 |
| `0x34` | Input rows | Must equal weight columns |
| `0x38` | Input columns | Nonzero multiple of 8 |
| `0x3c` | Format | Bits 1:0 = mode (must be 3); bits 3:2 = signedness |
| `0x40` | Bias | 32-bit ADDIN applied to each inner-tile dot product |
| `0x44` | Compute mask | Low 10 bits, passed to Cleopatra |
| `0x48..0x64` | Write mask | Eight 32-bit words, low word first; normally all ones |

The IO configuration region starts at `0x20` with this version of
`hwpe_ctrl_slave` configured with **zero generic registers**. Do not confuse
these byte offsets with `DIMC_REG_*`, which are indices relative to that region.
Software must program all configuration fields, including all eight mask words.

Signedness: 0 = both unsigned, 1 = signed weights, 2 = signed inputs,
3 = both signed. Results accumulate modulo 2^32. The existing Cleopatra bias
semantics add the bias once per `l` contribution: a completed output includes
`L*bias`, rather than a single bias for the entire dot product.

The default HWPE-Ctrl setup provides two contexts. Software can acquire and
program the next context while the current job is running. Configuration is
latched at job start; subsequent register writes do not change an active job.
Request IDs use the HWPE-Ctrl core bitmask convention (core 0 uses ID 1).
`evt_o[core][0]` reports completion; `[core][1]` reports configuration rejection.
The error bit in the extension register is cleared on the next job start or
soft clear. Invalid jobs complete with error and issue no memory requests.

Example sequence:

1. Put full matrices in memory and reserve a separate output region.
2. Read Acquire until it returns a nonnegative context/job identifier.
3. Write addresses, dimensions, format (3 for unsigned 8-bit), bias (normally
   zero), compute mask (normally zero), and all write-mask words (`0xffffffff`).
4. Write zero to Trigger.
5. Wait for the completion event or the standard HWPE-Ctrl finished indication.
6. Check the error status, then read the output matrix from memory.

## Completion and abort

Normal completion requires both datapath completion and the streamer's final
output write completion. Input-source completion alone is insufficient.

On soft clear, new memory bursts stop. Already started read bursts drain and
their data is discarded; an already started output burst finishes using the
held accumulator tile. Only then are the datapath/FIFOs/streamer cleared.
This prevents old read responses or stalled writes from corrupting a later job.
An aborted job's output is incomplete and must be discarded. Wait until the
DIMC busy bit is zero before acquiring/programming another job after soft clear.
Progress requires memory eventually to grant requests and return responses.

Configuration checks reject unsupported dimensions, mode, base alignment,
and any matrix address range that wraps the 32-bit address space. This version
does not handle partial tiles, memory access faults, or cache coherency; a
system integration must provide accessible, coherent accelerator memory.

## Simulation and limits

```bash
module load bender/0.31.0
module load questasim/2024.3
make sim-top
```

`tb_dimc_top` loads the original untiled stimulus files into simulated memory,
programs the real register interface, and checks the resulting matrix in memory.
The memory model exercises queued requests, variable response latency, request
stalls, request stability, address bounds, and output guard bytes. Tests cover
the full Python golden matrix, smaller runtime shapes, signed operands/bias,
queued configurations, invalid configuration, and abort during reads/writes.
`make sim-datapath` remains the focused datapath regression.

The input transpose buffer, memory bandwidth, and output acceptance can all
limit throughput. This is a functionally tested integration, not a synthesized
area/timing result or a claim of maximum throughput.
