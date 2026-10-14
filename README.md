# Cleopatra DIMC
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
