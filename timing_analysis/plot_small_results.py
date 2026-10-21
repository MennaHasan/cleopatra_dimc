""" TO RUN THIS - change 100 to any size limit

python3 timing_analysis/plot_small_results.py --max-size 100
"""

"""Plot existing experiment results for K × L × Q up to a chosen limit.

Usage: python3 timing_analysis/plot_small_results.py --max-size 100 [path/to/results.csv]
Writes results_small_size.png beside the CSV without running simulations.
"""

import argparse
from pathlib import Path

from run_experiments import plot_results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "csv", type=Path, nargs="?",
        default=Path(__file__).resolve().parent / "results" / "results.csv",
        help="Existing experiment results.csv",
    )
    parser.add_argument(
        "--max-size", type=int, default=100,
        help="Maximum K × L × Q included in the plot (default: 100)",
    )
    args = parser.parse_args()
    if args.max_size <= 0:
        parser.error("--max-size must be greater than zero")
    output = args.csv.parent / "results_small_size.png"
    plot_results(args.csv, output, max_size=args.max_size)
    print("Plot: {}".format(output))


if __name__ == "__main__":
    main()
