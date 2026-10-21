# Cleopatra DIMC

## STEPS:

### modules load

```bash
module load bender/0.31.0
module load questasim
module load synopsys/syn/
```

### 1. comment or uncomment test defines to select comiled tests

### 2. compile modules

```bash
make hw-clean
make hw-all
```

### 3. run testbenches

```bash
make sim-single
make sim-dual
make sim-cleopatra
make sim-double-buffering
make sim-datapath
make sim-top STIM_SEED=20261007
```

### 4. generate timing analysis reports

```bash
python3 timing_analysis/timing_analysis.py timing_analysis/timing_report_1.txt
python3 timing_analysis/timing_analysis.py timing_analysis/timing_report_1.txt --start 150 --end 250
```

### 6. run experiement

```bash
python3 timing_analysis/run_experiments.py
```

to Preview the selected sizes without running simulations:

```bash
python3 timing_analysis/run_experiments.py --dry-run
```

## Simulation checks:

- `make sim-top` runs all 30 numbered end-to-end tests. Use `TOP_TEST=N`
  to select one; custom `K`, `L`, and `Q` require `TOP_TEST=1`.
- The default stimulus dimensions are K=4, L=3, Q=2, matching the fixed
  datasets used by the datapath and double-buffering testbenches.
- Outputs are `weights @ inputs + bias`, with bias added once per output
  element and results reduced modulo 2^32. Inputs/weights are 8-bit values;
  the format register independently selects signed weights and inputs.
- Each module has one 256-bit memory port. Reads return in order, at least
  one clock after the request grant, and responses stay valid until ready.
  Writes complete at the request grant and do not return responses. Input
  bases must be 8-byte aligned; weight and output bases must be 32-byte aligned.
  Inputs use packed `[q][l]` tiles; weights and results are row-major.
- Batch simulations return success only after their explicit pass flag is
  set. Test 1 publishes its timing report after both output matrices pass
  numerical comparison; plotting preserves the source TXT report.
- Tests 26–30 add mixed signed operands, masks, bias/overflow, invalid jobs,
  and valid input addresses that are not 32-byte aligned. The memory model
  checks accepted addresses and request stability during grant stalls.
- `make hw-clean` removes the complete `sim/` output tree (including its
  downloaded Bender binary), `.bender/` dependency cache, generated stimulus
  TXT files and empty output folders, standalone timing reports/plots/CSVs, root simulation outputs,
  and Python caches. Everything inside `timing_analysis/experiments/` is
  preserved. Dependencies are fetched again on the next build.
- Compilation generates `sim/modelsim.ini` from the installed Questa defaults
  using `vmap -c`. It is ignored by Git and removed by `make hw-clean`, along
  with any root-level `modelsim.ini` left by a manual simulator invocation.

## NOTES:

### 1. To use GUI

```bash
make sim-single GUI=1
make sim-dual GUI=1
make sim-cleopatra GUI=1
```

### 2. Adding signals innside Questasim

**A. for sim-dual**

```tcl
restart -f
env tb_dimc_dual
add wave clk COMPE RCSN READYN PSOUT SOUT RES_OUT out_data out_empty out_pop
```

**B. for sim-cleopatra**

```tcl
restart -f
env tb_cleopatra
add wave clk COMPE acc_clear_i acc_o
add wave sim:/tb_cleopatra/i_dut/READYN
add wave sim:/tb_cleopatra/i_dut/out_data
```

### 3. run simulation in Questasim

```tcl
run -all
```
