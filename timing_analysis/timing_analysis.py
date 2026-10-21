"""Extract inclusive activity windows and plot four DIMC macros.

Usage: python3 timing_analysis/timing_analysis.py timing_analysis/timing_report_1.txt
Add --start/--end to zoom, or --show to open an interactive matplotlib window.
Outputs retain the source report number. Zooms add a cycle-range suffix;
repeated outputs add a version suffix. This script never creates TXT reports.
Each run also creates a separate summary PNG for the full experiment.
The input TXT report is preserved unchanged.
Intervals describe reported windows, including any stalls inside those windows.
FIFO activity is attributed to its destination macro; the FIFO is shared.
"""

import argparse
import csv
import re
from pathlib import Path


MACROS = ((1, 1), (1, 2), (2, 3), (2, 4))
ACTIVITIES = ("WEIGHT LOAD", "VECTOR LOAD TO FIFO", "VECTOR LOAD TO MACRO", "COMPUTE")
COLORS = ("#2374AB", "#00A896", "#FF6500", "#459544")
EVENT = re.compile(
    r"Module (\d+) macro (\d+) tile-product (\d+)(?: vector (\d+))?: "
    r"(WEIGHT LOAD|VECTOR LOAD TO FIFO|VECTOR LOAD TO MACRO|VECTOR LOAD|TILE COMPUTE|COMPUTE) "
    r"(START|END)(?: \[(\d+)\.\.(\d+)\])?"
)


def read_report(path):
    """Return per-macro (cycle, activities) entries, intervals, tile flags, and N."""
    intervals = {key: {action: [] for action in ACTIVITIES} for key in MACROS}
    tile_starts = {key: [] for key in MACROS}
    pending = {}
    cycle = None
    last_cycle = 0
    with Path(path).open() as report:
        for line in report:
            total = re.search(r"Total elapsed cycles: (\d+)", line)
            heading = re.search(r"\[TEST1 TIMING\] CYCLE (\d+)", line)
            if total:
                last_cycle = max(last_cycle, int(total.group(1)))
            if heading:
                cycle = int(heading.group(1))
                last_cycle = max(last_cycle, cycle)
            match = EVENT.search(line)
            if not match:
                continue
            if cycle is None:
                raise ValueError("Activity event found before a cycle heading")
            module, macro, tile, vector, action, phase, lo, hi = match.groups()
            key = (int(module), int(macro))
            if key not in intervals:
                raise ValueError("Unexpected module/macro: {}".format(key))
            if action == "TILE COMPUTE":
                if phase == "START":
                    tile_starts[key].append((cycle, int(tile)))
                continue
            if action == "VECTOR LOAD":  # Accept older reports too.
                action = "VECTOR LOAD TO MACRO"
            identity = (key, tile, vector, action)
            if phase == "START":
                if identity in pending:
                    raise ValueError("Duplicate START: {}".format(line.strip()))
                pending[identity] = cycle
            else:
                start = pending.pop(identity, None)
                if start is None or lo is None or hi is None:
                    raise ValueError("Unmatched or malformed END: {}".format(line.strip()))
                lo, hi = int(lo), int(hi)
                if lo != start or hi != cycle or hi < lo:
                    raise ValueError("Inconsistent interval: {}".format(line.strip()))
                intervals[key][action].append((lo, hi))
                last_cycle = max(last_cycle, hi)
    if pending:
        raise ValueError("Report ends with {} unfinished activities".format(len(pending)))
    if not any(intervals[key][action] for key in MACROS for action in ACTIVITIES):
        raise ValueError("No activity intervals found")
    data = {}
    for key in MACROS:
        activities = [set() for _ in range(last_cycle + 1)]
        for action, windows in intervals[key].items():
            for start, end in windows:
                for index in range(start, end + 1):
                    activities[index].add(action)
        data[key] = [(index, tuple(action for action in ACTIVITIES if action in active))
                     for index, active in enumerate(activities)]
    return data, intervals, tile_starts, last_cycle


def write_csv(path, data, tile_starts):
    with Path(path).open("w", newline="") as output:
        writer = csv.writer(output)
        writer.writerow(("module", "macro", "cycle", "activities", "tile_compute_start"))
        for key in MACROS:
            flags = dict(tile_starts[key])
            for cycle, actions in data[key]:
                writer.writerow((*key, cycle, " | ".join(actions) or "IDLE", flags.get(cycle, "")))


def read_summary(path):
    """Read dimensions/configuration and count completed tiles from SV events."""
    text = Path(path).read_text()
    modules = {}
    current = None
    for line in text.splitlines():
        heading = re.fullmatch(r"\s*Module (\d+):\s*", line)
        if heading:
            current = int(heading.group(1))
            modules.setdefault(current, {})
        matrix = re.search(
            r"(Input|Kernel|Output):\s*(\d+) x (\d+) = (\d+) elements; "
            r"(\d+) bits/element(?:; (\d+) bits total)?", line)
        if matrix and current is not None:
            label, rows, cols, elements, bits, total = matrix.groups()
            total = total or str(int(elements) * int(bits))
            modules[current][label] = tuple(map(int, (rows, cols, elements, bits, total)))
    if not modules or any(set(m) != {"Input", "Kernel", "Output"} for m in modules.values()):
        raise ValueError("Summary requires complete matrix sizes in the TXT header")
    elapsed = re.search(r"Total elapsed cycles: (\d+)", text)
    if not elapsed or int(elapsed.group(1)) == 0:
        raise ValueError("Summary requires a positive total elapsed cycle count")
    precision = re.search(r"Precision used: (\d+) bits", text)
    signing = re.search(r"Signing used: ([^\n]+)", text)
    region = re.search(r"Macro weights region: (\d+) rows x (\d+) bits", text)
    vector_region = re.search(r"Macro input vector region: (\d+) bits", text)
    observed = {module: set() for module in modules}
    weight_loads = {module: set() for module in modules}
    for match in EVENT.finditer(text):
        module, macro, tile, vector, action, phase, _, _ = match.groups()
        module = int(module)
        if module in modules and phase == "END":
            if action == "TILE COMPUTE":
                observed[module].add((int(macro), int(tile)))
            elif action == "WEIGHT LOAD":
                weight_loads[module].add((int(macro), int(tile)))
    # Dimensions give scalar MACs; observed SV events give executed tile counts.
    macs = {m: sizes["Kernel"][0] * sizes["Kernel"][1] * sizes["Input"][1]
            for m, sizes in modules.items()}
    return {
        "modules": modules, "cycles": int(elapsed.group(1)), "macs": macs,
        "precision": int(precision.group(1)) if precision else next(iter(modules.values()))["Kernel"][3],
        "signing": signing.group(1) if signing else "Not recorded in this report",
        "weight_region": int(region.group(1)) * int(region.group(2)) if region else 32768,
        "vector_region": int(vector_region.group(1)) if vector_region else 1024,
        "observed": {m: len(tiles) for m, tiles in observed.items()},
        "weight_loads": {m: len(tiles) for m, tiles in weight_loads.items()},
    }


def plot_summary(path, summary):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    fig = plt.figure(figsize=(14, 9), facecolor="#F2F5FA")
    fig.text(.06, .94, "Cleopatra Experiment Summary", fontsize=24, weight="bold", color="#17324D")
    fig.text(.06, .895, "Precision: {} bits     |     {}".format(
        summary["precision"], summary["signing"]), fontsize=12)
    cycles = summary["cycles"]
    modules = list(sorted(summary["modules"]))
    cards = [(.06, "ELAPSED CYCLES", "{:,}".format(cycles))]
    for index, module in enumerate(modules):
        cards.append((.38 + .32 * index, "MODULE {} — MACs / CYCLE".format(module),
                      "{:.4f}".format(summary["macs"][module] / cycles)))
    for x, label, value in cards:
        fig.text(x, .82, label, fontsize=10, color="#53657B")
        fig.text(x, .77, value, fontsize=25, weight="bold", color="#17324D")
    rows = []
    for label in ("Kernel", "Input", "Output"):
        rows.append([label + " matrix"] + [
            "{} × {} · {} bits/element\n{:,} elements".format(*summary["modules"][m][label][:2],
                summary["modules"][m][label][3], summary["modules"][m][label][2])
            for m in modules])
    rows.extend([
        ["Weight matrix tiles (capacity)"] + ["{:g}".format(
            summary["modules"][m]["Kernel"][4] / summary["weight_region"]) for m in modules],
        ["Needed MACs\noutput rows × inner elements × output columns"] + [
            "{} × {} × {} = {:,}".format(summary["modules"][m]["Kernel"][0],
                summary["modules"][m]["Kernel"][1], summary["modules"][m]["Input"][1],
                summary["macs"][m]) for m in modules],
        ["Measured MACs/cycle per module"] + ["{:.4f}".format(summary["macs"][m] / cycles) for m in modules],
    ])
    ax = fig.add_axes((.06, .32, .88, .40))
    ax.axis("off")
    table = ax.table(cellText=rows, colLabels=["Metric"] + ["Module {}".format(m) for m in modules],
                     cellLoc="left", loc="center", bbox=(0, 0, 1, 1))
    table.auto_set_font_size(False)
    table.set_fontsize(10)
    for (row, col), cell in table.get_celld().items():
        cell.set_edgecolor("#D5DFEA")
        cell.set_facecolor("#17324D" if row == 0 else ("#FFFFFF" if row % 2 else "#E7EDF5"))
        if row == 0:
            cell.set_text_props(color="white", weight="bold")
    fig.text(.06, .275, "Macro capacity: weights = 32 rows × 1024 bits; input vector = {:,} bits".format(
        summary["vector_region"]), fontsize=11)
    theoretical = 32768 / 420
    fig.text(.06, .235, "MAC comparison — single macro model, 8 vectors, 8-bit operands", fontsize=14, weight="bold")
    fig.text(.06, .200, "MACs = 32 × 128 × 8 = 32,768     |     Cycles = 128 + 8 × (4 + 32) + 4 = 420", fontsize=12)
    fig.text(.06, .165, "Theoretical MACs/cycle = 32,768 / 420 = {:.2f}".format(theoretical), fontsize=14, color="#17324D")
    comparisons = ["Module {}: {:.2f} measured / {:.2f} model = {:.2f}×".format(
        m, summary["macs"][m] / cycles, theoretical, summary["macs"][m] / cycles / theoretical)
        for m in modules]
    fig.text(.06, .130, "    |    ".join(comparisons), fontsize=11)
    fig.text(.06, .098, "Notes", fontsize=10, weight="bold", color="#53657B")
    fig.text(.06, .030,
             "• The model excludes transfers into input/weight FIFOs and output-memory writes; measured cycles include them.",
             fontsize=9, color="#53657B")
    fig.savefig(str(path), dpi=200, facecolor=fig.get_facecolor())
    plt.close(fig)


def plot_timeline(path, intervals, tile_starts, last_cycle, start=0, end=None, show=False):
    import matplotlib
    if not show:
        matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.lines import Line2D
    from matplotlib.patches import Patch

    end = last_cycle if end is None else end
    if not 0 <= start <= end <= last_cycle:
        raise ValueError("Plot range must satisfy 0 <= start <= end <= {}".format(last_cycle))
    fig, axes = plt.subplots(4, 1, sharex=True, figsize=(18, 10))
    for ax, key in zip(axes, MACROS):
        for lane, (action, color) in enumerate(zip(ACTIVITIES, COLORS)):
            windows = [(lo, hi - lo + 1) for lo, hi in intervals[key][action]]
            prominent = action == "VECTOR LOAD TO MACRO"
            ax.broken_barh(windows, (lane - .4, .8), facecolors=color,
                           edgecolors=color,
                           linewidth=1.5 if prominent else .3, zorder=4 if prominent else 2)
        visible_flags = [cycle for cycle, _ in tile_starts[key] if start <= cycle <= end]
        ax.scatter(visible_flags, [3.43] * len(visible_flags), marker="v",
                   color="#9228D3", s=55, zorder=6, clip_on=False)
        ax.set_yticks(range(4))
        ax.set_yticklabels(ACTIVITIES, fontsize=9)
        ax.set_ylim(-.6, 3.7)
        ax.set_xlim(start - .5, end + .5)
        ax.set_title("Module {} macro {}".format(*key), loc="left", fontsize=11)
        ax.grid(axis="x", alpha=.2)
        ax.set_axisbelow(True)
    axes[-1].set_xlabel("Cycle (interval endpoints included)")
    handles = [Patch(facecolor=color, label=action) for action, color in zip(ACTIVITIES, COLORS)]
    handles.append(Line2D([], [], color="#9228D3", marker="v", linestyle="None",
                          label="TILE COMPUTE START"))
    fig.legend(handles=handles, loc="upper center", ncol=5, fontsize=9)
    fig.suptitle("Cleopatra Activity Timeline", y=.945)
    fig.tight_layout(rect=(0, 0, 1, .92))
    fig.savefig(str(path), dpi=200)
    if show:
        plt.show()
    plt.close(fig)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("--start", type=int, default=0, help="First plotted cycle")
    parser.add_argument("--end", type=int, help="Last plotted cycle")
    parser.add_argument("--show", action="store_true", help="Open an interactive plot")
    args = parser.parse_args()
    match = re.fullmatch(r"timing_report_(\d+)\.txt", args.report.name)
    if not match:
        parser.error("Input must be named timing_report_<number>.txt")
    data, intervals, flags, last_cycle = read_report(args.report)
    summary = read_summary(args.report)
    output_dir = Path(__file__).resolve().parent
    output_dir.mkdir(parents=True, exist_ok=True)
    name = "timing_report_{}".format(match.group(1))
    if args.start != 0 or args.end is not None:
        name += "_cycles_{}_{}".format(args.start, last_cycle if args.end is None else args.end)
    base = output_dir / name
    version = 1
    while (base.with_suffix(".csv").exists() or base.with_suffix(".png").exists()
           or Path(str(base) + "_summary.png").exists()):
        version += 1
        base = output_dir / (name + "_v{}".format(version))
    csv_path = base.with_suffix(".csv")
    plot_path = base.with_suffix(".png")
    summary_path = Path(str(base) + "_summary.png")
    plot_timeline(plot_path, intervals, flags, last_cycle, args.start, args.end, args.show)
    write_csv(csv_path, data, flags)
    plot_summary(summary_path, summary)
    print("Covered cycles 0..{} for all four macros".format(last_cycle))
    print("Source: {}\nData: {}\nPlot: {}".format(args.report, csv_path, plot_path))
    print("Summary: {}".format(summary_path))


if __name__ == "__main__":
    main()
