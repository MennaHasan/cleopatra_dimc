# Cleopatra DIMC

The standalone accelerator now contains **two complete modules** under one
controller: module 1 has macros 1–2, module 2 has macros 3–4. Each has its own
FSMs, 256 accumulators, three FIFOs and dedicated input/weight/output memory
channels. Configuration and start are broadcast; stalls are local. Overall
completion waits for both modules, including final output writes.

Each module has three programmable base addresses. Shared arithmetic settings
and both address triplets form one job configuration. See the
[integration guide](docs/dimc_integration.md) for all six ports and the register
map, including the new module 2 address registers at `0x68`–`0x70`.

## Reusable dual-macro core

Implementation of two independently controlled dimc macros with shared FIFO
data paths and double buffering. `clk` and `rst_n` are shared. Every other dimc
control input is provided independently using `_m0` and `_m1` ports. `sel` only
chooses which macro output is forwarded to the output FIFO; it does not gate
either macro's input controls.

STEPS:

1. modules load
   module load bender/0.31.0
   module load questasim
2. comment or uncomment test defines to select comiled tests
3. compile modules 
4. run testbenches
   make hw-clean
   make hw-all
   make sim-single
   make sim-dual
   make sim-cleopatra
   make sim-double-buffering
   make sim-datapath
5. To use GUI
   make sim-single GUI=1
   make sim-dual GUI=1
   make sim-cleopatra GUI=1
6. Adding signals innside Questasim
   A. for sim-dual
   restart -f
   env tb_dimc_dual
   add wave clk COMPE RCSN READYN PSOUT SOUT RES_OUT out_data out_empty out_pop

B. for sim-cleopatra
restart -f
env tb_cleopatra
add wave clk COMPE acc_clear_i acc_o
add wave sim:/tb_cleopatra/i_dut/READYN
add wave sim:/tb_cleopatra/i_dut/out_data

6. run simulation in Questasim
   run -all

## Full standalone accelerator test

```bash
module load bender/0.31.0
module load questasim/2024.3
make sim-top
# For the graphical simulator:
make sim-top GUI=1
```

`tb_dimc_top` programs the real HWPE-Ctrl registers and tests `dimc_top`
against simulated HCI memory on six dedicated channels. It loads full row-major
matrices from
`double_buffering_kernel_stim.txt` and `double_buffering_feature_stim.txt`;
each RTL streamer assembles its own tiles. Each module loads its own independently generated operand files into separate
memory regions. Both output matrices are checked directly
in memory against reference dot products and each module’s Python golden
matrix.

The regression covers independent holds on all six channels, runtime dimensions,
signed arithmetic, bias, queued jobs, invalid configuration and module 2 addresses,
and abort/restart during reads and writes, including asymmetric completion.
Success prints `[DIMC_TOP] ALL TESTS PASSED`. No board or MAGIA build
is required. `make sim-datapath` still runs the standalone datapath regression.

See [the standalone integration guide](docs/dimc_integration.md) for the
register map, memory-port widths, alignment, and software launch sequence.

## Measure cycles for one job

```bash
make sim-top-timing
# Same one-job experiment with simulated memory stalls:
make sim-top-timing TIMING_STALLS=1
# GUI is also supported:
make sim-top-timing GUI=1
```

This runs one shared job with two independent matrix multiplications, each with
weights **128x384**, inputs **384x16**,
result **128x16** (`K=4, L=3, Q=2`). The terminal prints measured cumulative
cycles when tile products 1–5 finish, full-job cycles including output writes,
and the number of tile products completed by each of the four macros.
Reports identify module 1 or 2 and include overall completion for both. They also
print
minimum/average/maximum weight-section latency from memory request to macro
write, and from weight FIFO acceptance to macro write. Results still undergo
the golden-matrix check.

For each macro, the report also gives sample count and minimum/average/maximum
cycles for:

- Loading a full **32x128 weight tile**: its first memory request through its
  last section written into the macro (not loading the entire large matrix).
- Loading one input vector: first through fourth feature-buffer section write.
- Computing one matvec: row 0 issued through its 32nd result accumulated.

The vector measurement excludes memory fetching before the first feature write.
Four consecutive section writes span **three elapsed cycles** under the same
edge-difference convention used for all the timing measurements.

Cycle zero is the rising edge accepting the datapath start. Tile completion
is the edge accumulating its 256th result. Per-module completion remembers its
datapath and streamer finishing; overall job completion is the controller's
completion edge after both modules' writes. Latencies are edge differences
(adjacent clock edges = one cycle). Memory-request timing begins on the first
rising edge observing that request, including time waiting for a grant;
FIFO timing begins when its data is accepted into the FIFO. These measurements
include overlapping activity and should not be added together.

To regenerate all stimulus and golden files with a new reproducible seed:

```bash
make stim STIM_SEED=20261007
make sim-top STIM_SEED=20261007
```

Module 1 and module 2 load separate file sets, generated with seeds
`STIM_SEED + 1` and `STIM_SEED + 2`. Use the same `STIM_SEED` with other
simulation targets to retain the new data across regressions.
