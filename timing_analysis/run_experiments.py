"""Run independent Test 1 experiments and collect per-module MACs and cycles.

Default: 25 distinct mixed combinations, with each of K, L, Q between 5 and 20.
Combinations where K=L=Q are excluded from the sampled sweep.
A final baseline run uses K=L=Q=1, making 26 experiments by default.
Use --k K --l L --q Q for a single custom experiment.
Dimensions are passed at runtime; source defaults are never rewritten.
"""

import argparse
import csv
import random
import shlex
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

from timing_analysis import read_summary


ROOT = Path(__file__).resolve().parents[1]
FIELDS = ("k", "l", "q", "module_1_seed", "module_2_seed",
          "macs_per_module", "elapsed_cycles", "report")


def execute(command, log):
    """Stream subprocess output to disk; stop immediately on a failed command."""
    print(shlex.join(command) if hasattr(shlex, "join") else " ".join(map(shlex.quote, command)), flush=True)
    with Path(log).open("w") as output:
        result = subprocess.run(command, cwd=str(ROOT), stdout=output, stderr=subprocess.STDOUT)
    if result.returncode:
        raise RuntimeError("Command failed (exit {}); inspect {}".format(result.returncode, log))


def collect_result(report, k, l, q, seeds):
    summary = read_summary(report)
    expected = (k * 32) * (l * 128) * (q * 8)
    for module in (1, 2):
        sizes = summary["modules"].get(module, {})
        if ("Kernel" not in sizes or "Input" not in sizes or "Output" not in sizes
                or sizes["Kernel"][:2] != (k * 32, l * 128)
                or sizes["Input"][:2] != (l * 128, q * 8)
                or sizes["Output"][:2] != (k * 32, q * 8)
                or summary["macs"][module] != expected):
            raise ValueError("Report dimensions/MACs do not match this experiment: {}".format(report))
    return dict(zip(FIELDS, (k, l, q, seeds[0], seeds[1], expected,
                            summary["cycles"], str(report))))


def plot_results(csv_path, output):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    with Path(csv_path).open() as source:
        rows = list(csv.DictReader(source))
    if not rows:
        raise ValueError("No completed experiments in {}".format(csv_path))
    rows.sort(key=lambda row: int(row["k"]) * int(row["l"]) * int(row["q"]))
    sizes = [int(row["k"]) * int(row["l"]) * int(row["q"]) for row in rows]
    macs = [int(row["macs_per_module"]) for row in rows]
    cycles = [int(row["elapsed_cycles"]) for row in rows]
    fig, axes = plt.subplots(1, 2, figsize=(14, 5))
    axes[0].plot(sizes, cycles, "o-", color="#2374AB")
    axes[0].set_xlabel("Matrix size (K × L × Q)")
    axes[0].set_ylabel("Total elapsed cycles (full run)")
    axes[0].set_title("Workload versus measured cycles")
    axes[1].plot(sizes, [m / c for m, c in zip(macs, cycles)], "o-", color="#FF6500")
    axes[1].set_xlabel("Matrix size (K × L × Q)")
    axes[1].set_ylabel("Measured MACs/cycle per module")
    axes[1].set_title("Experimental throughput")
    for ax in axes:
        ax.grid(alpha=.25)
        ax.set_axisbelow(True)
    fig.suptitle("Cleopatra Matrix Size Experiments — Per Module")
    fig.tight_layout(rect=(0, 0, 1, .93))
    fig.savefig(str(output), dpi=200)
    plt.close(fig)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--first", type=int, default=5, help="Minimum value for each of K, L, Q")
    parser.add_argument("--last", type=int, default=20, help="Maximum value for each of K, L, Q")
    parser.add_argument("--count", type=int, default=25, help="Number of distinct mixed combinations")
    for dimension in ("k", "l", "q"):
        parser.add_argument("--" + dimension, type=int, help="Single-run tile count; supply all three")
    parser.add_argument("--seed", type=int, help="Reproduce the experiment seed sequence; otherwise random")
    parser.add_argument("--output-dir", type=Path, help="New directory for logs, reports, stimuli and results")
    parser.add_argument("--skip-compile", action="store_true", help="Use an already compiled sim/work library")
    parser.add_argument("--dry-run", action="store_true", help="Print planned dimensions and seeds without writing files")
    parser.add_argument("--plot-only", type=Path, metavar="CSV", help="Plot existing results without running simulation")
    args = parser.parse_args()
    if args.plot_only:
        output = args.plot_only.with_name(args.plot_only.stem + "_plot.png")
        version = 1
        while output.exists():
            version += 1
            output = args.plot_only.with_name(args.plot_only.stem + "_plot_v{}.png".format(version))
        plot_results(args.plot_only, output)
        print("Plot: {}".format(output))
        return
    dimensions = (args.k, args.l, args.q)
    rng = random.Random(args.seed) if args.seed is not None else random.SystemRandom()
    if any(value is not None for value in dimensions):
        if any(value is None or value < 1 for value in dimensions):
            parser.error("Supply positive --k, --l and --q together")
        sizes = [dimensions]
    else:
        if not 1 <= args.first <= args.last:
            parser.error("Require 1 <= --first <= --last")
        candidates = [(k, l, q)
                      for k in range(args.first, args.last + 1)
                      for l in range(args.first, args.last + 1)
                      for q in range(args.first, args.last + 1)
                      if not k == l == q]
        if not 1 <= args.count <= len(candidates):
            parser.error("--count must be between 1 and {} for this mixed-combination range".format(len(candidates)))
        sizes = rng.sample(candidates, args.count)
        sizes.sort(key=lambda size: (size[0] * size[1] * size[2], size))
        sizes.append((1, 1, 1))
    used_seeds = set()
    plan = []
    for size in sizes:
        seeds = []
        while len(seeds) < 2:
            seed = rng.randrange(1, 2**31)
            if seed not in used_seeds:
                used_seeds.add(seed)
                seeds.append(seed)
        plan.append((size, seeds))
        print("K={}, L={}, Q={}; module seeds {} / {}".format(*size, *seeds))
    if args.dry_run:
        return
    for tool in ("vsim",) if args.skip_compile else ("make", "vsim", "vlib"):
        if shutil.which(tool) is None:
            parser.error("{} is not on PATH; run in your Questa/Bender environment".format(tool))
    # Unique output root prevents old results/reports from being reused.
    output = args.output_dir or ROOT / "timing_analysis" / "experiments" / datetime.now().strftime("run_%Y%m%d_%H%M%S_%f")
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    csv_path = output / "results.csv"
    with csv_path.open("w", newline="") as destination:
        writer = csv.DictWriter(destination, fieldnames=FIELDS)
        writer.writeheader()
        destination.flush()
        if not args.skip_compile:
            execute(["make", "hw-compile"], output / "compile.log")
        try:
            for (k, l, q), seeds in plan:
                experiment = output / "k{}_l{}_q{}".format(k, l, q)
                experiment.mkdir()
                for module, seed in enumerate(seeds, 1):
                    stim = experiment / "module_{}".format(module)
                    execute([sys.executable, str(ROOT / "stimuli/double_buffering_stim.py"),
                             "--k", str(k), "--l", str(l), "--q", str(q), "--seed", str(seed),
                             "--outdir", str(stim)], experiment / "stimulus_{}.log".format(module))
                execute(["vsim", "-c", "-voptargs=+acc", "-l", str(experiment / "simulation.log"),
                         "-lib", "sim/work", "tb_dimc_top", "+TEST=1", "+MATRIX_K={}".format(k),
                         "+MATRIX_L={}".format(l), "+MATRIX_Q={}".format(q),
                         "+STIM_DIR_1={}".format(experiment / "module_1"),
                         "+STIM_DIR_2={}".format(experiment / "module_2"),
                         "+TIMING_REPORT_DIR={}".format(experiment),
                         "-do", "do scripts/run_top.tcl"], experiment / "simulation.stdout")
                report = experiment / "timing_report_1.txt"
                row = collect_result(report, k, l, q, seeds)
                writer.writerow(row)
                destination.flush()
                print("Completed: {:,} MACs/module; {:,} cycles; {:.4f} MACs/cycle/module".format(
                    row["macs_per_module"], row["elapsed_cycles"],
                    row["macs_per_module"] / row["elapsed_cycles"]), flush=True)
        finally:
            # Preserve and plot all completed runs even if a later run fails.
            destination.flush()
            with csv_path.open() as source:
                completed = list(csv.DictReader(source))
            if completed:
                plot_results(csv_path, output / "results.png")
    print("Results: {}\nPlot: {}".format(csv_path, output / "results.png"))


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, OSError) as error:
        print("Experiment failed: {}".format(error), file=sys.stderr)
        sys.exit(1)
