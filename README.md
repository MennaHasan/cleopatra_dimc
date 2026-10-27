# Cleopatra DIMC

## STEPS:

### modules load

```bash
module load bender/0.31.0
module load questasim
module load synopsys/syn/
```

### 1. comment or uncomment test defines to select compiled tests

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

### 4. To use Questasim GUI and add signals innside it

#### To use GUI:

```bash
make sim-cleopatra GUI=1
```

#### Adding signals

```tcl
restart -f
env tb_cleopatra
add wave clk COMPE acc_clear_i acc_o
add wave sim:/tb_cleopatra/i_dut/READYN
add wave sim:/tb_cleopatra/i_dut/out_data
```

#### Running simulation

```tcl
run -all
```

### 5. generate timing analysis reports

```bash
python3 timing_analysis/timing_analysis.py timing_analysis/timing_report_1.txt
python3 timing_analysis/timing_analysis.py timing_analysis/timing_report_1.txt --start 150 --end 250
```

### 6. run experiement

```bash
python3 timing_analysis/run_experiments.py
```

to run the plots on the same csv results file

```bash
python3 timing_analysis/run_experiments.py --plot-only
```

to Preview the selected sizes without running simulations:

```bash
python3 timing_analysis/run_experiments.py --dry-run
```
### 7. Get synthesis results 
#### Step 3
```bash
cd cleopatra_gf22
make tech_init
make synthesis
```

#### Step 2
copy results files and name them 11_area_{f}.rpt, 11_timing_{f}.rpt, 11_area.rpt to folder Synthesis_resutls 

#### Step 3
```bash
python3 Synthesis_results/synthesis_report.py
```
