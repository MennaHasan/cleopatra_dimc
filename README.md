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

make sim-top STIM_SEED=20261007

1. To use GUI
   make sim-single GUI=1
   make sim-dual GUI=1
   make sim-cleopatra GUI=1
8. Adding signals innside Questasim
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
Success prints `[DIMC_TOP] ALL SELECTED TESTS PASSED`. No board or MAGIA build
is required. `make sim-datapath` still runs the standalone datapath regression.

See [the standalone integration guide](docs/dimc_integration.md) for the
register map, memory-port widths, alignment, and software launch sequence.

## Run numbered top-level tests

`tb_dimc_top` contains 22 separate tests, each with a numbered description and
PASS/FAIL result. Test 1 supplies both modules with full matrices and checks
their outputs against Python golden files. The remaining tests each focus on
one behavior: dimensions, memory stalls, signed arithmetic, bias, one held
channel, abort/draining, restart, queued jobs, or invalid configuration.
Timing monitors and internal RTL probes have been removed.

```bash
# All 22 tests:
make sim-top STIM_SEED=20261007
# Test 1 only: one shared job, both modules checked against goldens:
make sim-top TOP_TEST=1 STIM_SEED=20261007
# Test 4 only: signed arithmetic:
make sim-top TOP_TEST=4 STIM_SEED=20261007
```

See the [test list](docs/dimc_integration.md#numbered-top-level-tests).

To regenerate all stimulus and golden files with a new reproducible seed:

```bash
make stim STIM_SEED=20261007
make sim-top STIM_SEED=20261007
```

Module 1 and module 2 load separate file sets, generated with seeds
`STIM_SEED + 1` and `STIM_SEED + 2`. Use the same `STIM_SEED` with other
simulation targets to retain the new data across regressions.
