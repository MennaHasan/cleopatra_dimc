"""Run Test 1 experiments for one DIMC module with two macros.

Default: 58 distinct experiments across three controlled sweeps:
Q=1..20 with K=L=1; L=1..20 with K=Q=1; K=1..20 with L=Q=1.
The shared K=L=Q=1 baseline is run once.
The default run also samples 30 unique K/L/Q configurations from 5..30; their
CSV and plots are kept separate from the controlled sweeps.
Use --k K --l L --q Q for a single custom experiment.
Dimensions are passed at runtime; source defaults are never rewritten.

Run experiments and produce all plots:
    python3 timing_analysis/run_experiments.py
Analyze the existing timing_analysis/results/results.csv without simulation:
    python3 timing_analysis/run_experiments.py --plot-only
Analyze a different saved CSV:
    python3 timing_analysis/run_experiments.py --plot-only path/to/results.csv

Both modes produce four PNGs: K, L and Q versus MACs/cycle with the other
two dimensions fixed at 1, plus a K × L × Q versus MACs/cycle comparison.
New runs write results.csv and results_random.csv, each with four plots in
timing_analysis/results/;
logs, timing reports and stimuli go in timing_analysis/run_<id>/ beside results/.
"""

import argparse
import csv
from collections import defaultdict
import random
import shlex
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

from timing_analysis import read_summary


ROOT = Path(__file__).resolve().parents[1]
FIELDS = ("k", "l", "q", "precision", "stimulus_seed",
          "macs_per_module", "elapsed_cycles", "report")


def execute(command, log):
    """Stream subprocess output to disk; stop immediately on a failed command."""
    print(shlex.join(command) if hasattr(shlex, "join") else " ".join(map(shlex.quote, command)), flush=True)
    with Path(log).open("w") as output:
        result = subprocess.run(command, cwd=str(ROOT), stdout=output, stderr=subprocess.STDOUT)
    if result.returncode:
        raise RuntimeError("Command failed (exit {}); inspect {}".format(result.returncode, log))


def collect_result(report, k, l, q, seeds, precision=8):
    summary = read_summary(report)
    inner_elements = l * (1024 // precision)
    expected = (k * 32) * inner_elements * (q * 8)
    sizes = summary["modules"].get(1, {})
    if (set(summary["modules"]) != {1}
            or "Kernel" not in sizes or "Input" not in sizes or "Output" not in sizes
            or sizes["Kernel"][:2] != (k * 32, inner_elements)
            or sizes["Input"][:2] != (inner_elements, q * 8)
            or sizes["Output"][:2] != (k * 32, q * 8)
            or sizes["Kernel"][3] != precision or sizes["Input"][3] != precision
            or summary["macs"][1] != expected):
        raise ValueError("Report dimensions/MACs do not match this experiment: {}".format(report))
    return dict(zip(FIELDS, (k, l, q, precision, seeds[0], expected,
                            summary["cycles"], str(report))))


def plot_paths(output):
    """Names of the four requested throughput plots."""
    output = Path(output)
    names = ("k", "l", "q", "klq")
    return tuple(output.with_name(output.stem + "_{}_vs_macs_per_cycle.png".format(name))
                 for name in names)


def plot_results(csv_path, output):
    """Generate four throughput plots from a saved experiment CSV."""
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.ticker import MaxNLocator, FormatStrFormatter

    with Path(csv_path).open(newline="") as source:
        reader = csv.DictReader(source)
        required = {"k", "l", "q", "macs_per_module", "elapsed_cycles"}
        missing = required.difference(reader.fieldnames or [])
        if missing:
            raise ValueError("Missing CSV columns: {}".format(", ".join(sorted(missing))))
        rows = []
        for line_number, row in enumerate(reader, 2):
            try:
                values = {field: int(row[field]) for field in required}
            except (ValueError, TypeError) as error:
                raise ValueError("Invalid numeric data on CSV line {}".format(line_number)) from error
            if any(value <= 0 for value in values.values()):
                raise ValueError("Dimensions, MACs and cycles must be positive on CSV line {}".format(line_number))
            rows.append(values)
    if not rows:
        raise ValueError("No completed experiments match the selection in {}".format(csv_path))
    outputs = plot_paths(output)
    dimensions = ("k", "l", "q")
    has_controlled = any(
        all(row[name] == 1 for name in dimensions if name != dimension)
        for row in rows for dimension in dimensions)
    for dimension, destination in zip(dimensions, outputs):
        fixed = tuple(name for name in dimensions if name != dimension)
        controlled_rows = [row for row in rows if all(row[name] == 1 for name in fixed)]
        selected_rows = controlled_rows if controlled_rows else rows
        fig, ax = plt.subplots(figsize=(14, 6.5))
        if not controlled_rows:
            label = "Random configurations"
        else:
            label = None
        selected_rows.sort(key=lambda row: row[dimension])
        x_values = [row[dimension] for row in selected_rows]
        throughput = [row["macs_per_module"] / row["elapsed_cycles"] for row in selected_rows]
        # Preserve every measured point and connect means of repeated x values.
        by_x = defaultdict(list)
        for x_value, rate in zip(x_values, throughput):
            by_x[x_value].append(rate)
        if len(by_x) > 1:
            x_line = sorted(by_x)
            ax.plot(x_line, [sum(by_x[x]) / len(by_x[x]) for x in x_line],
                    color="#2563eb", linewidth=1.4, alpha=0.8)
        ax.scatter(x_values, throughput, s=40, color="#2563eb", marker="o",
                   alpha=0.8, edgecolors="white", linewidths=0.4, zorder=3,
                   label=label)
        for x_value, rate in zip(x_values, throughput):
            ax.annotate("{:.2f}".format(rate), (x_value, rate), xytext=(0, 6),
                        textcoords="offset points", ha="center", va="bottom",
                        fontsize=8, color="#1d4ed8",
                        bbox=dict(facecolor="white", edgecolor="none", alpha=0.8, pad=0.4))
        ax.set_xlabel("{} (tile count)".format(dimension.upper()))
        ax.set_ylabel("Measured MACs/cycle per module")
        title_detail = ("Fixed: {}=1, {}=1".format(fixed[0].upper(), fixed[1].upper())
                        if controlled_rows else "Other dimensions vary")
        ax.set_title("{} versus MACs/cycle\n{}".format(
            dimension.upper(), title_detail), fontsize=17, weight="bold")
        ax.xaxis.set_major_locator(MaxNLocator(integer=True))
        ax.yaxis.set_major_locator(MaxNLocator(nbins=8))
        ax.yaxis.set_major_formatter(FormatStrFormatter("%.1f"))
        ax.set_ylim(0, max(throughput, default=1) * 1.15)
        ax.grid(alpha=0.25)
        ax.set_axisbelow(True)
        fig.subplots_adjust(left=0.09, right=0.98, top=0.84, bottom=0.13)
        fig.savefig(str(destination), dpi=200, facecolor="white")
        plt.close(fig)
    fig, ax = plt.subplots(figsize=(11, 6))
    # Broad solid underlay, narrower dashes, and fine dots remain visible even
    # at identical coordinates. Nested hollow markers preserve coincident points.
    sweep_styles = (
        ("k", "#2563eb", "-", 5.0, "o", 12, 3),
        ("l", "#0d9488", "--", 3.2, "s", 8, 4),
        ("q", "#ea580c", ":", 1.8, "^", 4.5, 5),
    )
    label_offsets = {"k": 12, "l": 24, "q": -12}
    for dimension, color, style, width, marker, marker_size, order in sweep_styles:
        fixed = tuple(name for name in dimensions if name != dimension)
        experiments = [row for row in rows if all(row[name] == 1 for name in fixed)]
        if not experiments:
            continue
        experiments.sort(key=lambda row: row[dimension])
        sizes = [row["k"] * row["l"] * row["q"] for row in experiments]
        rates = [row["macs_per_module"] / row["elapsed_cycles"] for row in experiments]
        by_size = defaultdict(list)
        for size, rate in zip(sizes, rates):
            by_size[size].append(rate)
        x_line = sorted(by_size)
        ax.plot(x_line, [sum(by_size[x]) / len(by_size[x]) for x in x_line],
                color=color, linestyle=style, linewidth=width, marker=marker,
                markersize=marker_size, markerfacecolor="none", markeredgewidth=1.4,
                zorder=order, label="{} sweep ({}={} = 1)".format(
                    dimension.upper(), fixed[0].upper(), fixed[1].upper()))
        ax.scatter(sizes, rates, edgecolors=color, facecolors="none", marker=marker,
                   s=marker_size ** 2, linewidths=1.4, zorder=order + 0.1)
        for size, rate in zip(sizes, rates):
            ax.annotate("{:.2f}".format(rate), (size, rate),
                        xytext=(0, label_offsets[dimension]), textcoords="offset points",
                        ha="center", va="center", fontsize=7, color=color,
                        bbox=dict(facecolor="white", edgecolor="none", alpha=0.8, pad=0.3))
    # Keep older/custom CSV combinations visible without connecting unrelated runs.
    mixed = [row for row in rows if sum(row[name] != 1 for name in dimensions) > 1]
    if mixed:
        mixed_sizes = [row["k"] * row["l"] * row["q"] for row in mixed]
        mixed_rates = [row["macs_per_module"] / row["elapsed_cycles"] for row in mixed]
        ax.scatter(mixed_sizes, mixed_rates,
                   color="#64748b", marker="x",
                   label="Other combinations" if has_controlled else "Random configurations")
        for size, rate in zip(mixed_sizes, mixed_rates):
            ax.annotate("{:.2f}".format(rate), (size, rate), xytext=(0, 8),
                        textcoords="offset points", ha="center", va="bottom",
                        fontsize=7, color="#64748b")
    ax.set_xlabel("Workload size (K × L × Q)")
    ax.set_ylabel("Measured MACs/cycle per module")
    ax.set_title("K × L × Q versus MACs/cycle", fontsize=17, weight="bold")
    ax.xaxis.set_major_locator(MaxNLocator(integer=True))
    ax.yaxis.set_major_locator(MaxNLocator(nbins=8))
    ax.yaxis.set_major_formatter(FormatStrFormatter("%.1f"))
    all_rates = [row["macs_per_module"] / row["elapsed_cycles"] for row in rows]
    ax.set_ylim(0, max(all_rates, default=1) * 1.15)
    ax.grid(alpha=0.25)
    ax.set_axisbelow(True)
    ax.legend(handlelength=4)
    fig.tight_layout()
    fig.savefig(str(outputs[-1]), dpi=200, facecolor="white")
    plt.close(fig)
    return outputs



def plot_all_results(csv_path, output):
    """Generate and report only the four requested PNGs."""
    plots = plot_results(csv_path, output)
    for plot in plots:
        print("Plot: {}".format(plot))
    return plots


def run_plan(plan, precision, output, csv_path, plot_prefix):
    """Run one experiment plan and write only its own CSV and plots."""
    output.mkdir(parents=True)
    with Path(csv_path).open("w", newline="") as destination:
        writer = csv.DictWriter(destination, fieldnames=FIELDS)
        writer.writeheader()
        destination.flush()
        directory_counts = {}
        try:
            for (k, l, q), seed in plan:
                name = "k{}_l{}_q{}".format(k, l, q)
                directory_counts[name] = directory_counts.get(name, 0) + 1
                occurrence = directory_counts[name]
                if occurrence > 1:
                    name += "_repeat{}".format(occurrence)
                experiment = output / name
                experiment.mkdir()
                stim = experiment / "stimulus"
                execute([sys.executable, str(ROOT / "stimuli/double_buffering_stim.py"),
                         "--k", str(k), "--l", str(l), "--q", str(q), "--precision", str(precision),
                         "--seed", str(seed), "--outdir", str(stim)], experiment / "stimulus.log")
                execute(["vsim", "-c", "-voptargs=+acc", "-l", str(experiment / "simulation.log"),
                         "-lib", "sim/work", "tb_dimc_top", "+TEST=1", "+MATRIX_K={}".format(k),
                         "+MATRIX_L={}".format(l), "+MATRIX_Q={}".format(q),
                         "+PRECISION={}".format(precision), "+STIM_DIR_1={}".format(stim),
                         "+TIMING_REPORT_DIR={}".format(experiment),
                         "-do", "do scripts/run_top.tcl"], experiment / "simulation.stdout")
                report = experiment / "timing_report_1.txt"
                row = collect_result(report, k, l, q, (seed,), precision)
                writer.writerow(row)
                destination.flush()
                print("Completed: K={}, L={}, Q={}; {:,} MACs/module; {:,} cycles; "
                      "{:.4f} MACs/cycle/module".format(
                          k, l, q, row["macs_per_module"], row["elapsed_cycles"],
                          row["macs_per_module"] / row["elapsed_cycles"]), flush=True)
        finally:
            destination.flush()
            with Path(csv_path).open() as source:
                completed = list(csv.DictReader(source))
            if completed:
                plot_all_results(csv_path, plot_prefix)
    print("Results: {}".format(csv_path))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for dimension in ("k", "l", "q"):
        parser.add_argument("--" + dimension, type=int, help="Single-run tile count; supply all three")
    parser.add_argument("--precision", type=int, choices=(1, 2, 4, 8), default=8,
                        help="Operand precision for all experiments (default: 8)")
    parser.add_argument("--seed", type=int, help="Reproduce stimulus seeds; otherwise random")
    parser.add_argument("--output-dir", type=Path, help="New directory for logs, reports and stimuli; CSV/plots go in timing_analysis/results")
    parser.add_argument("--skip-compile", action="store_true", help="Use an already compiled sim/work library")
    parser.add_argument("--dry-run", action="store_true", help="Print planned dimensions and seeds without writing files")
    parser.add_argument("--plot-only", type=Path, nargs="?", metavar="CSV",
                        const=ROOT / "timing_analysis" / "results" / "results.csv",
                        help="Analyze a saved CSV without simulation (default: timing_analysis/results/results.csv)")
    args = parser.parse_args()
    if args.plot_only:
        output = args.plot_only.with_name(args.plot_only.stem + "_plot.png")
        version = 1
        while any(path.exists() for path in plot_paths(output)):
            version += 1
            output = args.plot_only.with_name(args.plot_only.stem + "_plot_v{}.png".format(version))
        plot_all_results(args.plot_only, output)
        return
    dimensions = (args.k, args.l, args.q)
    rng = random.Random(args.seed) if args.seed is not None else random.SystemRandom()
    if any(value is not None for value in dimensions):
        if any(value is None or value < 1 for value in dimensions):
            parser.error("Supply positive --k, --l and --q together")
        sizes = [dimensions]
    else:
        # Preserve sweep order while sharing the (1, 1, 1) baseline.
        sizes = [(1, 1, q) for q in range(1, 21)]
        sizes.extend((1, l, 1) for l in range(2, 21))
        sizes.extend((k, 1, 1) for k in range(2, 21))
    used_seeds = set()
    plan = []
    for index, size in enumerate(sizes, 1):
        seed = rng.randrange(1, 2**31)
        while seed in used_seeds:
            seed = rng.randrange(1, 2**31)
        used_seeds.add(seed)
        plan.append((size, seed))
        print("Experiment {}/{}: K={}, L={}, Q={}; stimulus seed {}".format(
            index, len(sizes), *size, seed))
    random_sizes = rng.sample([(k, l, q) for k in range(5, 31)
                               for l in range(5, 31) for q in range(5, 31)], 30)
    random_plan = []
    for index, size in enumerate(random_sizes, 1):
        seed = rng.randrange(1, 2**31)
        while seed in used_seeds:
            seed = rng.randrange(1, 2**31)
        used_seeds.add(seed)
        random_plan.append((size, seed))
        print("Random experiment {}/{}: K={}, L={}, Q={}; stimulus seed {}".format(
            index, len(random_sizes), *size, seed))
    if args.dry_run:
        return
    for tool in ("vsim",) if args.skip_compile else ("make", "vsim", "vlib"):
        if shutil.which(tool) is None:
            parser.error("{} is not on PATH; run in your Questa/Bender environment".format(tool))
    # Keep per-run artifacts and the controlled/random CSV and plot sets separate.
    results_dir = ROOT / "timing_analysis" / "results"
    results_dir.mkdir(parents=True, exist_ok=True)
    output = args.output_dir or results_dir.parent / datetime.now().strftime("run_%Y%m%d_%H%M%S_%f")
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    if not args.skip_compile:
        execute(["make", "hw-compile"], output / "compile.log")
    run_plan(plan, args.precision, output / "current", results_dir / "results.csv",
             results_dir / "results.png")
    run_plan(random_plan, args.precision, output / "random", results_dir / "results_random.csv",
             results_dir / "results_random.png")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, OSError) as error:
        print("Experiment failed: {}".format(error), file=sys.stderr)
        sys.exit(1)
