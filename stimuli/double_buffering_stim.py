#!/usr/bin/env python3
"""Generate independent tiled stimuli for the double-buffering testbench."""

import argparse
import random
from pathlib import Path
from typing import Dict, List, Tuple

# Full-matrix tile counts. Keep these aligned with tb_double_buffering.sv.
K = 4
L = 3
Q = 2

# Packed storage tile dimensions. Matrices below contain bytes; a byte holds
# 8/precision unsigned scalar elements (or one signed/unsigned 8-bit element).
M = 32
N_BITS = 1024
P = 8
ELEMENT_BITS = 8
N_ELEMENTS = N_BITS // ELEMENT_BITS
WEIGHT_MATRIX_ROWS = K * M
WEIGHT_MATRIX_COLS = L * N_ELEMENTS
INPUT_MATRIX_ROWS = L * N_ELEMENTS
INPUT_MATRIX_COLS = Q * P
BIAS = 0
UINT32_MASK = (1 << 32) - 1

Matrix = List[List[int]]
WeightTiles = Dict[Tuple[int, int], Matrix]
InputTiles = Dict[Tuple[int, int], Matrix]

DEFAULT_OUTPUT_DIR = Path(__file__).resolve().parent / "double_buffering"
ACCUMULATOR_OUTPUT_FILE = DEFAULT_OUTPUT_DIR / "double_buffering_accumulator_output.txt"
FINAL_OUTPUT_FILE = DEFAULT_OUTPUT_DIR / "double_buffering_final_matmul_output.txt"


def generate_random_matrix(rng: random.Random, rows: int, cols: int) -> Matrix:
    """Return a reproducible unsigned 8-bit matrix."""
    return [[rng.getrandbits(ELEMENT_BITS) for _ in range(cols)] for _ in range(rows)]


def matrix_tiling(
    weight_matrix: Matrix,
    input_matrix: Matrix,
) -> Tuple[WeightTiles, InputTiles]:
    """Split the full matrices into DIMC-sized MxN and NxP tiles."""
    weight_tiles = {}
    for k_index in range(len(weight_matrix) // M):
        for l_index in range(len(weight_matrix[0]) // N_ELEMENTS):
            row_start = k_index * M
            col_start = l_index * N_ELEMENTS
            weight_tiles[k_index, l_index] = [
                row[col_start:col_start + N_ELEMENTS]
                for row in weight_matrix[row_start:row_start + M]
            ]

    input_tiles = {}
    for l_index in range(len(input_matrix) // N_ELEMENTS):
        for q_index in range(len(input_matrix[0]) // P):
            row_start = l_index * N_ELEMENTS
            col_start = q_index * P
            input_tiles[l_index, q_index] = [
                row[col_start:col_start + P]
                for row in input_matrix[row_start:row_start + N_ELEMENTS]
            ]

    return weight_tiles, input_tiles


def write_tiled_weights(path: Path, tiles: WeightTiles) -> None:
    """Write one packed MxN kernel tile per line in [k,l] order."""
    with path.open("w", encoding="utf-8") as output:
        for tile_index in sorted(tiles):
            output.write(
                "".join(f"{value:02x}" for row in tiles[tile_index] for value in row)
                + "\n"
            )


def write_tiled_inputs(path: Path, tiles: InputTiles) -> None:
    """Write one packed NxP input tile per line in [q,l] order."""
    with path.open("w", encoding="utf-8") as output:
        for tile_index in sorted(tiles, key=lambda index: (index[1], index[0])):
            tile = tiles[tile_index]
            output.write(
                "".join(
                    f"{tile[row_index][col_index]:02x}"
                    for col_index in range(P)
                    for row_index in range(N_ELEMENTS)
                )
                + "\n"
            )


def calculate_golden_matmul(weight_matrix: Matrix, input_matrix: Matrix) -> Matrix:
    """Compute the full matrix product with one bias addition per output."""
    return calculate_top_golden(
        weight_matrix, input_matrix, len(weight_matrix) // M,
        len(weight_matrix[0]) // N_ELEMENTS, len(input_matrix[0]) // P,
        bias=BIAS,
    )


def calculate_top_golden(
    weights: Matrix, inputs: Matrix, nk: int, nl: int, nq: int,
    sign_mode: int = 0, bias: int = 0,
    compute_mask: int = 0, write_mask: int = (1 << 256) - 1,
    precision: int = 8,
) -> Matrix:
    """Dot products over precision-bit lanes in byte matrices, modulo 2**32.

    Inner dimensions are packed bytes. 1/2/4-bit lanes are always unsigned;
    sign_mode affects 8-bit lanes only. Masks apply before lane extraction.
    """
    # Match the RTL register slice: only the low ten bits reach the macro.
    compute_mask = int(compute_mask) & 0x3ff
    if precision not in (1, 2, 4, 8):
        raise ValueError("precision must be 1, 2, 4, or 8")
    def operand(value: int, signed: bool) -> int:
        return value - 256 if signed and value >= 128 else value

    def packed_product(weight_byte: int, input_byte: int) -> int:
        if precision == 8:
            return (operand(weight_byte, bool(sign_mode & 1))
                    * operand(input_byte, bool(sign_mode & 2)))
        lane_mask = (1 << precision) - 1
        return sum(((weight_byte >> bit) & lane_mask)
                   * ((input_byte >> bit) & lane_mask)
                   for bit in range(0, 8, precision))

    # Each memory section is byte-reversed on its way into the macro.
    # Sections 0..3 occupy increasing 256-bit positions in its 1024-bit row.
    masks = []
    for n in range(nl * N_ELEMENTS):
        byte_bit = (31 - n % 32) * 8
        row_bit = ((n % N_ELEMENTS) // 32) * 256 + byte_bit
        active = max(0, min(8, 1024 - compute_mask - row_bit))
        mask = (1 << active) - 1
        masks.append((mask & ((write_mask >> byte_bit) & 255), mask))

    return [
        [
            (sum(
                packed_product(weights[r][n] & masks[n][0], inputs[n][c] & masks[n][1])
                for n in range(nl * N_ELEMENTS)
            ) + bias) & UINT32_MASK
            for c in range(nq * P)
        ]
        for r in range(nk * M)
    ]


def write_matrix(path: Path, matrix: Matrix) -> None:
    with path.open("w", encoding="utf-8") as output:
        for row in matrix:
            output.write(" ".join(f"{value:08x}" for value in row) + "\n")


def write_u8_matrix(path: Path, matrix: Matrix) -> None:
    """Write an unsigned 8-bit matrix as one row per line."""
    with path.open("w", encoding="utf-8") as output:
        for row in matrix:
            output.write(" ".join(f"{value:02x}" for value in row) + "\n")


def reorganize_accumulator_output(
    accumulator_file: Path = ACCUMULATOR_OUTPUT_FILE,
    output_file: Path = FINAL_OUTPUT_FILE,
) -> None:
    """Reassemble saved M-by-P accumulator tiles into the full output matrix."""
    raw_values = [
        int(token, 16)
        for token in accumulator_file.read_text(encoding="utf-8").split()
    ]
    tile_elements = M * P
    expected_values = K * Q * tile_elements
    if len(raw_values) != expected_values:
        raise ValueError(
            f"Expected {expected_values} accumulator values, "
            f"but found {len(raw_values)}"
        )

    with output_file.open("w", encoding="utf-8") as output:
        for k_index in range(K):
            for row in range(M):
                final_row = []
                for q_index in range(Q):
                    tile_start = (k_index * Q + q_index) * tile_elements
                    for col in range(P):
                        final_row.append(raw_values[tile_start + row * P + col])
                output.write(" ".join(f"{value:08x}" for value in final_row) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, default=43)
    parser.add_argument("--outdir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--k", type=int, default=K, help="Kernel row tiles (32 rows each)")
    parser.add_argument("--l", type=int, default=L, help="Inner tiles (128 packed bytes each; 1024/precision elements)")
    parser.add_argument("--q", type=int, default=Q, help="Input column tiles (8 columns each)")
    parser.add_argument("--precision", type=int, choices=(1, 2, 4, 8), default=8,
                        help="Precision for the full Test 1 golden (default: 8)")
    parser.add_argument(
        "--untile-only",
        action="store_true",
        help="Only convert the saved accumulator tiles into the final matrix",
    )
    args = parser.parse_args()
    if min(args.k, args.l, args.q) < 1:
        parser.error("k, l, and q must be positive")
    if args.untile_only and (args.k, args.l, args.q) != (K, L, Q):
        parser.error("--untile-only currently supports the default dimensions only")

    if args.untile_only:
        reorganize_accumulator_output(
            args.outdir / ACCUMULATOR_OUTPUT_FILE.name,
            args.outdir / FINAL_OUTPUT_FILE.name,
        )
        return

    args.outdir.mkdir(parents=True, exist_ok=True)
    rng = random.Random(args.seed)

    # Full matrix shapes:
    #   weights = (K*M) x (L*N_ELEMENTS)
    #   inputs  = (L*N_ELEMENTS) x (Q*P)
    # Full, untiled matrices of unsigned 8-bit elements.
    kernel_stim = generate_random_matrix(
        rng,
        args.k * M,
        args.l * N_ELEMENTS,
    )
    feature_stim = generate_random_matrix(
        rng,
        args.l * N_ELEMENTS,
        args.q * P,
    )

    # software tiling done here 
    weight_tiles, input_tiles = matrix_tiling(kernel_stim, feature_stim)

    write_u8_matrix(
        args.outdir / "double_buffering_kernel_stim.txt",
        kernel_stim,
    )
    write_u8_matrix(
        args.outdir / "double_buffering_feature_stim.txt",
        feature_stim,
    )

    write_tiled_weights(
        args.outdir / "double_buffering_tiled_weights.txt",
        weight_tiles,
    )
    write_tiled_inputs(
        args.outdir / "double_buffering_tiled_inputs.txt",
        input_tiles,
    )
    write_matrix(
        args.outdir / "double_buffering_golden_matmul_output.txt",
        calculate_top_golden(kernel_stim, feature_stim, args.k, args.l, args.q, bias=BIAS),
    )

    # Preserve the existing 8-bit golden for legacy tests. A lower-precision
    # Test 1 reuses exactly the same packed bytes with a precision-specific golden.
    if args.precision != 8:
        write_matrix(args.outdir / f"double_buffering_golden_matmul_output_{args.precision}bit.txt",
                     calculate_top_golden(kernel_stim, feature_stim, args.k, args.l, args.q,
                                          bias=BIAS, precision=args.precision))

    # Test 31: lower precisions, multiple inner/output tiles, and unsigned
    # semantics even when both 8-bit sign-control bits are set.
    if args.k >= 2 and args.l >= 3 and args.q >= 2:
        for precision in (1, 2, 4):
            write_matrix(args.outdir / f"top_precision_{precision}bit_golden.txt",
                         calculate_top_golden(kernel_stim, feature_stim, 2, 3, 2,
                                              sign_mode=3, bias=-7, precision=precision))

    # Separate compact goldens keep tb_dimc_top focused on driving/checking.
    # Each specification is (K, L, Q, sign_mode, bias).
    top_tests = {
        "top_small_golden.txt": (1, 1, 1, 0, 0),
        "top_dimensions_golden.txt": (2, 1, 2, 0, 0),
        "top_signed_golden.txt": (1, 2, 1, 3, 0),
        "top_bias_golden.txt": (1, 2, 1, 0, -7),
        "top_queued_first_golden.txt": (1, 2, 1, 0, 1),
        "top_queued_second_golden.txt": (1, 2, 1, 3, -9),
        "top_mixed_01_golden.txt": (1, 3, 1, 1, -17),
        "top_mixed_10_golden.txt": (1, 3, 1, 2, 23),
        "top_wrap_golden.txt": (1, 3, 1, 0, 0x7fffffff),
    }
    for filename, settings in top_tests.items():
        if any(needed > available for needed, available in zip(settings[:3], (args.k, args.l, args.q))):
            continue
        write_matrix(args.outdir / filename,
                     calculate_top_golden(kernel_stim, feature_stim, *settings))

    if args.l >= 3:
        pattern = int("0123456789abcdef13579bdf2468ace0fedcba98765432100f1e2d3c4b5a6978", 16)
        for mask in (5, 257, 512, 1023):
            write_matrix(args.outdir / f"top_mask_{mask}_golden.txt",
                         calculate_top_golden(kernel_stim, feature_stim, 1, 3, 1,
                                              bias=-11, compute_mask=mask,
                                              write_mask=pattern))

    if args.l >= 3:
        # Test 32 resets macros before each job, so disabled writes retain zero.
        # Keep bit zero enabled to exercise the last surviving bit at mask=1023.
        write_pattern = int("0123456789abcdef13579bdf2468ace0fedcba98765432100f1e2d3c4b5a6979", 16)
        for precision in (1, 2, 4, 8):
            for compute_mask in (0, 1, 5, 257, 1023, 1024):
                write_matrix(args.outdir / f"top_mask_{precision}bit_{compute_mask}_golden.txt",
                             calculate_top_golden(kernel_stim, feature_stim, 1, 3, 1,
                                                  bias=-11, precision=precision,
                                                  compute_mask=compute_mask,
                                                  write_mask=write_pattern))

    print(f"Double-buffering stimulus written to {args.outdir.resolve()}")


if __name__ == "__main__":
    main()
