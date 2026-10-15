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

All addresses are 32-bit byte addresses. Each inner block (`dimc_module`)
exports one 256-bit HCI initiator: `tcdm` for module 1 and `tcdm_2` for module 2.
These replace the previous six top-level ports. Input reads, weight reads,
and output writes arbitrate dynamically inside each module.

The arbiter uses round-robin priority among eligible requests and locks the
selected request until granted. One active-read owner bit routes responses
to the weight or input source; an outstanding-read counter allows up to 32
reads in flight. All reads from a source drain before switching sources.
Writes can still use the port while reads are outstanding. Responses must
be returned in order and held until `r_ready`. Writes complete at the request
grant and do not produce responses. Soft clear drains traffic before resetting
the streamers; the arbiter retains ownership until each response is consumed.

The two ports may connect to one shared memory address space or separate
memories. Software must allocate nonoverlapping output regions. Input and
weight regions may intentionally be shared.

Memory contains row-major 8-bit weights, packed 8-bit input vectors, and
row-major little-endian 32-bit results. The logical matrix shapes are weights
`(K*32, L*128)`, inputs `(L*128, Q*8)`, and results `(K*32, Q*8)`. Both modules
use the same positive `K`, `L`, `Q`. Inputs must be packed before the job starts.

Input bases must be 8-byte aligned; weight and output bases must be 32-byte
aligned. The controller validates alignment and 32-bit end-address bounds
for both address triplets before either module starts. Current supported
mode is `2'b11` (8-bit operation).

## Input packing and FIFO scheduling

Inputs use the order already produced by `double_buffering_tiled_inputs.txt`:
input tiles are stored in `[q][l]` order, with `l` advancing fastest. Each tile
contains vectors 0 through 7, each with 128 consecutive eight-bit elements.
One tile occupies **1,024 bytes**, or **32 consecutive 256-bit beats**.

For local vector `c` (0..7) and element `r` (0..127), its byte address is:

```text
input_addr + (q * L + l) * 1024 + c * 128 + r
```

The same input tiles are reread for each weight-row group `k`. The existing
`hci_core_source` reads each tile directly into the **8 x 256-bit input FIFO**.
Fixed byte-order wiring maps the little-endian memory lanes to the macro's
MSB-first section order. There is no custom input-reader module, transpose
buffer, or full input-tile storage in the streamer.

For each tile product, the streamer completes its 128-beat weight transfer
before starting its 32-beat input transfer. The next tile's weight transfer
waits until the preceding input transfer has drained into the datapath.
This prevents a response stalled by the small input FIFO from blocking weight
responses needed for computation on the shared, ordered response channel.
The existing arbiter still routes responses according to their request source;
no input-credit counter or extra response buffer is added. Output writes may
still arbitrate for the shared port while reads are active.
One read-phase FSM and one shared `(k,l,q)` index set sequence both transfers,
advancing to the next tile only when its input transfer finishes.

Each block retains a weight FIFO of 128 x 256 bits and one shared macro-result
FIFO of **32 x 32 bits**. `LOAD_FIRST` consumes vector 0 immediately; it never
waits for a full 32-section tile to fit in the input FIFO. Later vectors stream
during `RUN`. Once vector 7 is in the active macro, the FIFO head belongs to
the next tile and its first vector can load into the inactive macro. Separate
current/next input counters preserve ordering across the macro switch.

The result FIFO accepts at most one scalar per cycle and drains one scalar
per cycle whenever nonempty. Starting empty, occupancy is at most one:
an initial push fills one entry, and every later push is matched by a pop.
External output stalls hold the completed tile in the accumulators rather
than blocking this drain. A simulation assertion fails if the FIFO reaches
capacity, so a dropped pipeline result cannot pass silently.

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

`N_CONTEXT` defaults to **2**. The active job and one queued job retain
separate configuration. A third acquire fails until a context is released.
Soft clear discards all queued jobs after draining the active traffic.

`dimc_ctrl` uses the original `hwpe_ctrl_slave` and `hwpe_ctrl_regfile` from
the locked hwpe-ctrl dependency, without local copies or changes. STATUS
(`0x0c`) retains one byte per context: context `i` occupies bits `[8*i +: 8]`,
with value 1 when occupied and 0 when free. The two contexts use the low
two bytes of the original 32-bit status register.

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
make sim-top                  # all 25 tests, default K=4 L=3 Q=2
make sim-top TOP_TEST=1
```

The top-level TB loads each module's input matrices, weight matrices, and Python
golden results directly from files. Module 1 reads `stimuli/double_buffering/`;
module 2 reads `stimuli/double_buffering_module2/`. Both directories contain
`double_buffering_kernel_stim.txt`, `double_buffering_tiled_inputs.txt`, and
`double_buffering_golden_matmul_output.txt`. The Python generator uses separate
seeds for the two modules. Separate base addresses and distinct reference
results catch accidental sharing of data or address paths.
The TB reads packed input tiles directly from `double_buffering_tiled_inputs.txt`.
`fill_memory()` copies each selected tile into memory, with its first file byte
at the lowest address; no raw input array or row-to-vector repacking is used.
For smaller jobs, it selects tiles using the source matrix's `L` stride.
Weight loading and independent golden-result checking remain row-major.

Use `make stim STIM_SEED=20261007` to regenerate all testbench stimulus/golden
files reproducibly. The single-macro and Cleopatra tests 1/2 use that seed;
module 1/double-buffering uses seed + 1, module 2 uses seed + 2, and Cleopatra
test 3 uses seed + 3. To regenerate and test together, use e.g.
`make sim-top STIM_SEED=20261007`. Pass the same seed to other `make sim-*`
targets so their automatic stimulus generation keeps the selected dataset.
The top TB also accepts `+STIM_DIR_1=...` and `+STIM_DIR_2=...` to select other
compatible file directories.
The streamers read/write simulated memory. The TB compares every result against
Python golden files and checks output guard bytes. Small, signed, biased, and
queued tests use separate compact `top_*_golden.txt` files generated alongside
the full-matrix golden. `tb_dimc_top` contains the shared sparse byte array and directly drives both
HCI memory interfaces in its `memory_handling` blocks. These blocks check
request bounds/direction, write accepted output beats into the array, and
queue input/weight read responses until their configured delivery cycle and
DIMC's `r_ready`. They preserve consecutive read acceptance and the existing
stall/delay tests. No interconnect or bank modules are instantiated.

Regression covers both modules, signed arithmetic, bias, queued contexts,
invalid dimensions, module 2 address alignment/overflow, independent holds
on input, weight, and output request classes on both shared ports, asymmetric completion, and abort/restart.
Tests hold a channel indefinitely until the other module has completed;
this verifies independent progress rather than just different latencies.

## Numbered top-level tests

Each test resets its setup and prints its number, purpose, and PASS or FAIL.
Test helpers drive the peripheral bus, initialize memory, wait for public
status/events, and compare output memory with Python golden files. Test 1 also
enables the passive observer in `tb/tb_dimc_test1_timing.sv`, which reads internal
macro activity without changing the job or its handshakes.

| Test | Checks |
|---|---|
| 1 | Full matrix multiplication in both modules against Python goldens |
| 2 | Different matrix dimensions |
| 3 | Memory stalls |
| 4 | Signed arithmetic |
| 5 | Bias |
| 6 | Module 1 input channel held; module 2 finishes |
| 7 | Module 1 weight channel held; module 2 finishes |
| 8 | Module 1 output channel held; module 2 finishes |
| 9 | Module 2 input channel held; module 1 finishes |
| 10 | Module 2 weight channel held; module 1 finishes |
| 11 | Module 2 output channel held; module 1 finishes |
| 12 | Abort drains outstanding reads |
| 13 | Abort waits for module 1's stalled output burst |
| 14 | Abort waits for module 2's stalled output burst |
| 15 | Restart after abort without resetting the accelerator |
| 16 | Queued jobs retain independent configuration |
| 17 | Reject incompatible dimensions |
| 18 | Reject module 1 unaligned output address |
| 19 | Reject module 2 unaligned output address |
| 20 | Reject module 1 weight-address overflow |
| 21 | Reject module 2 weight-address overflow |
| 22 | Reject unsupported compute mode |
| 23 | Two occupied contexts, third-acquire rejection, original byte status layout, configuration isolation, and two queue wraparounds |
| 24 | Abort a full queue, discard queued jobs, then restart |
| 25 | 47-cycle read responses under shared-port contention and grant stalls |

Run all tests with `make sim-top`, or select one using `make sim-top TOP_TEST=N`.
At the simulator level, use `+TEST=N`; `+TEST=0` is the default and runs all 25.
A failed check stops the simulation with the test number and reason. A timeout
also names the active test. The final summary states the number of passed tests.
Test 1 writes `timing_analysis/timing_report_<N>.txt` (or the directory selected by `+TIMING_REPORT_DIR=...`),
choosing the next unused run number so previous reports remain intact. It starts
with the measured total
elapsed cycles and each module's input, kernel, and output matrix sizes. This
report contains only testbench timing output, without the simulator startup
banner. It then lists a shared cycle timeline for both modules, which is also
printed in the simulator transcript. Cycle 0 is acceptance
of the software start request; the total ends at the final output memory write
grant across both modules. Events on the same edge appear under the same cycle
heading, with separate module/macro/task labels. `OVERLAP` lines identify
loading the next macro while the active macro computes.

Each weight load, vector load, vector computation, tile-product computation,
and output-tile write prints its start/end cycles and elapsed time. Loading
intervals measure actual macro writes (first to 128th weight write, first to
fourth feature write), rather than upstream memory requests or FIFO residence.
Vector computation runs from row 0 issue to the 32nd result accumulation;
tile-product computation ends after 256 results accumulate. Output writing runs
from the first to the 32nd memory grant for that output tile. Elapsed time means
`end - start`: 128 consecutive write edges span 127 cycles. Overlapping
intervals must not be added to obtain total job time.

For test 1 (`K=4, L=3, Q=2`), each module processes 24 tile-products in
`(k,q,l)` order, with `l` changing fastest. Every three tile-products accumulate
one complete output tile, giving eight output tiles per module. The observer
checks that all 24 weight loads, 192 vector loads/computations, and eight output
writes were observed before declaring timing complete.
Run just this report with `make sim-top TOP_TEST=1`; it is also printed when
test 1 runs in the full suite. Other tests do not enable timing observation.
The old separate `sim-top-timing` target remains removed.
Lower-level single-module tests remain available for the reusable datapath/core.

### Test 1 with different matrix sizes

The generator accepts `--k`, `--l`, and `--q` tile counts. For a 64x256 kernel
and 256x8 input, generate independent datasets and run test 1 as follows after
compiling (`make hw-compile`):

```sh
python3 stimuli/double_buffering_stim.py --seed 20261011 --k 2 --l 2 --q 1 --outdir stimuli/top_64x256_256x8_module1
python3 stimuli/double_buffering_stim.py --seed 20261012 --k 2 --l 2 --q 1 --outdir stimuli/top_64x256_256x8_module2
vsim -c -voptargs=+acc -lib sim/work tb_dimc_top +TEST=1 +MATRIX_K=2 +MATRIX_L=2 +MATRIX_Q=1 +STIM_DIR_1=stimuli/top_64x256_256x8_module1 +STIM_DIR_2=stimuli/top_64x256_256x8_module2 -do 'do scripts/run_top.tcl'
```

`MATRIX_K/L/Q` describe the source files and set test 1's job dimensions. The
current TB storage supports K=1..4, L=1..4, Q=1..2. Other numbered tests require
the default 4/3/2 source matrices. Reports include dimensions and the next unused
run number, so the existing `sim/test1_timing_report.txt` and earlier runs remain
intact.

## Performance checks

The inline memory handling in `tb_dimc_top` accepts queued reads and returns
ordered delayed responses; it does not limit the accelerator to one read per
round trip. Memory stalls, delayed responses, and concurrent reads/writes are
exercised through the top-level tests. There is no separate mux testbench.

For timing runs, `+MIN_MACS_PER_CYCLE=100` makes Test 1 fail below that per-module
throughput. Choose a threshold appropriate for the matrix size: small jobs pay
startup and final-write costs. `+QUIET_TIMING` suppresses console cycle events
while retaining the report timeline. `+SUMMARY_TIMING` also omits the timeline
from the report, for large performance checks. Ordinary experiment runs still
produce the full timeline and recompile the updated RTL by default.

**Historical measurements before removal of the row-major input reader and
transpose buffers**, with the same operand files and two-cycle response delay:

| K/L/Q | Previous shared-port cycles | Pipelined cycles | Previous MACs/cycle | Pipelined MACs/cycle |
|---|---:|---:|---:|---:|
| 1/1/1 | 813 | 556 | 40.3050 | 58.9353 |
| 4/3/2 | 18,878 | 7,560 | 41.6587 | 104.0254 |
| 12/15/17 | 2,951,372 | 901,333 | 33.9741 | 111.2464 |

These historical entries are per module, include startup and final writes, and passed
full output comparisons for both modules. The 25-test suite, Q=3/Q=5 row
packing cases, and queue-saturation arbiter test also passed. The original
six-port single-tile run took 498 cycles; the pipelined shared port still
has an initial bandwidth cost, even though long jobs recover computation overlap.

The packed-input simplification has not been compiled, simulated, or timed;
verification was explicitly deferred for this change.
