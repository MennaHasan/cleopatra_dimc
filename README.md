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

**python3 timing_analysis/timing_analysis.py timing_analysis/timing_report_1.txt**

python3 timing_analysis/timing_analysis.py timing_analysis/timing_report_1.txt --start 150 --end 250



to run experiement

```
python3 timing_analysis/run_experiments.py
```

to Preview the selected sizes without running simulations:

```
python3 timing_analysis/run_experiments.py --dry-run
```


1. To use GUI
   make sim-single GUI=1
   make sim-dual GUI=1
   make sim-cleopatra GUI=1
2. Adding signals innside Questasim
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
