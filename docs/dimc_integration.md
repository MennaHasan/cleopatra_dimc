# Two-module DIMC integration

`dimc_top` contains one shared `dimc_ctrl` and two instances of
`dimc_module`. Each module contains a `dimc_datapath` (including Cleopatra)
and a `dimc_streamer`. Module 1 contains macros 1 and 2; module 2 contains
macros 3 and 4. RTL macro ports remain locally named `m0` and `m1`.

Each module has 256 accumulators and three dedicated FIFOs: input, weight,
and macro-result FIFO. The macro-result FIFO feeds the accumulators. The
streamer reads the completed 32-by-8 accumulator tile directly and writes
32 output beats; there is no additional FIFO after the accumulators.

## Shared commands and independent progress

The controller broadcasts the same configuration bundle, datapath-start,
streamer-start, abort, and clear signals to both modules. Computation settings
are shared; the bundle contains a separate address triplet for each module.
`dimc_module` selects its own addresses before passing configuration to its
streamer. Each datapath and streamer has its own FSM, counters, buffers,
and handshakes. Corresponding macros follow the same schedule but can run at
different times when their channels stall.

Datapath-start initializes both modules. Once both datapaths report setup
ready, one shared streamer-start launches both streamers. Subsequent stalls
are local to each module; an early-finishing module remains idle while the
other completes. No new shared job starts until both modules finish.

The controller remembers each datapath and streamer completion pulse
independently. Overall completion requires all four completions, including
all output memory grants. These pulses need not occur on the same cycle.
One HWPE completion event is generated for the shared job. An invalid job
instead produces an error completion without issuing memory requests.

Soft clear broadcasts abort. Both streamers drain outstanding reads and
finish any already-started output burst before the controller broadcasts
clear. An aborted job does not generate a successful completion event.

## Memory ports

All addresses are 32-bit byte addresses. Each module has three independent
HCI initiator ports; the top level does not arbitrate them.

| Module | Input reads (64 bits) | Weight reads (256 bits) | Result writes (256 bits) |
|---|---|---|---|
| 1 | `input_tcdm` | `kernel_tcdm` | `output_tcdm` |
| 2 | `input_tcdm_2` | `kernel_tcdm_2` | `output_tcdm_2` |

Connect all six ports in the integrating system. Each can have independent
request grants and read-response latency. They may connect to a shared
memory address space or to separate memories. In a shared memory space,
software must allocate output regions so that unintended overwrites cannot
occur. Input or weight regions may intentionally be shared.

Memory contains row-major 8-bit operands and little-endian 32-bit results.
For each module, weights have shape `(K*32, L*128)`, inputs `(L*128, Q*8)`,
and results `(K*32, Q*8)`. Both modules use the same positive `K`, `L`, `Q`.
The streamer performs tiling and input transposition in hardware.

Input bases must be 8-byte aligned; weight and output bases must be 32-byte
aligned. The controller validates alignment and 32-bit end-address bounds
for both address triplets before either module starts. Current supported
mode is `2'b11` (8-bit operation).

## Configuration register map

These offsets are relative to the accelerator's peripheral base. IO register
index `i` maps to byte offset `0x20 + 4*i`. Existing offsets are preserved;
module 2 addresses are appended. Software must program all six addresses.
Values below are pointers to matrix memory, not peripheral-register addresses.

| Offset | IO index | Field | Scope |
|---|---|---|---|
| `0x20` | 0 | `input_addr` | Module 1 |
| `0x24` | 1 | `kernel_addr` | Module 1 |
| `0x28` | 2 | `output_addr` | Module 1 |
| `0x2c` | 3 | `weight_rows` | Shared |
| `0x30` | 4 | `weight_cols` | Shared |
| `0x34` | 5 | `input_rows` | Shared; equals `weight_cols` |
| `0x38` | 6 | `input_cols` | Shared |
| `0x3c` | 7 | Format: mode `[1:0]`, sign `[3:2]` | Shared |
| `0x40` | 8 | Bias (`ADDIN` once per inner tile) | Shared |
| `0x44` | 9 | Compute mask `[9:0]` | Shared |
| `0x48`–`0x64` | 10–17 | 256-bit write mask, low word first | Shared |
| `0x68` | 18 | `input_addr_2` | Module 2 |
| `0x6c` | 19 | `kernel_addr_2` | Module 2 |
| `0x70` | 20 | `output_addr_2` | Module 2 |

The HWPE extension status register at `0x18` exposes:

| Bit | Meaning |
|---|---|
| 0 | Overall controller busy |
| 1 | Configuration error |
| 2 | Module 1 job pending/in progress |
| 3 | Module 2 job pending/in progress |
| 4 | Module 1 completion remembered |
| 5 | Module 2 completion remembered |

Completion bits clear when a new job is accepted or on reset/soft clear.
After a successful job with no queued successor, status is `0x30`.
Busy bits describe the shared job's pending modules, including launch and
abort handling; they are not individual FIFO-ready signals.

## Software sequence

1. Acquire a HWPE context by reading `0x04`; bit 31 set indicates failure.
2. Program both address triplets and all shared computation settings.
3. Write `0x00` to commit and trigger the shared job.
4. Wait for the HWPE completion event, then check error/status and consume
   both output matrices. A queued successor can keep the controller busy.

Writing `0x14` requests soft clear. Wait for overall busy to become zero
before reusing memory or launching a replacement job after an abort.

## Simulation

```bash
module load bender/0.31.0 questasim/2024.3
make sim-top
make sim-top-timing
make sim-top-timing TIMING_STALLS=1
```

The top-level TB loads each module's input matrices, weight matrices, and Python
golden results directly from files. Module 1 reads `stimuli/double_buffering/`;
module 2 reads `stimuli/double_buffering_module2/`. Both directories contain
`double_buffering_kernel_stim.txt`, `double_buffering_feature_stim.txt`, and
`double_buffering_golden_matmul_output.txt`. The Python generator uses separate
seeds for the two modules. Separate base addresses and distinct reference
results catch accidental sharing of data or address paths.

Use `make stim STIM_SEED=20261007` to regenerate all testbench stimulus/golden
files reproducibly. The single-macro and Cleopatra tests 1/2 use that seed;
module 1/double-buffering uses seed + 1, module 2 uses seed + 2, and Cleopatra
test 3 uses seed + 3. To regenerate and test together, use e.g.
`make sim-top STIM_SEED=20261007`. Pass the same seed to other `make sim-*`
targets so their automatic stimulus generation keeps the selected dataset.
The top TB also accepts `+STIM_DIR_1=...` and `+STIM_DIR_2=...` to select other
compatible file directories.
The streamers read/write simulated memory; the TB checks every result,
request bounds, transfer counts, and output guard bytes.

Regression covers both modules, signed arithmetic, bias, queued contexts,
invalid dimensions, module 2 address alignment/overflow, independent holds
on each of the six channels, asymmetric completion, and abort/restart.
Tests hold a channel indefinitely until the other module has completed;
this verifies independent progress rather than just different latencies.

Timing mode reports each module's tile and full-job timing, plus overall
completion after both modules. Macro detail uses global numbers 1–4;
`local m0/m1` in summaries denotes the pair within that module. Lower-level
single-module tests remain available for the reusable datapath and core.
