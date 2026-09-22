# Double-buffering analysis for dual DIMC macros

## Compareing two schedules for MatMuls of weight tiles by input tiles.

Each DIMC macro stores:

one weight tile of 32 rows x 1024 bits; the input tile contains P = 8 vectors.  Each vector is 1024 bits, and the data path is 256 bits wide.

The macros cannot independently consume different words from the same FIFO in a cycle.

## Basic timing

| Operation                      | Data / work                           |                                    cycles |
| ------------------------------ | ------------------------------------- | ----------------------------------------: |
| Load one input vector          | 4 x 256-bit sections                  |                                         4 |
| Load one weight tile           | 32 rows x 4 sections                  |                                       128 |
| Calculate one row dot product  | One 1024-bit vector by one weight row |                             1 issue cycle |
| Produce one full MatVec result | 32 row dot products                   |                           32 issue cycles |
| Pipeline drain after final row | Four pipeline stages                  | about 3 additional cycles to output-valid |

The current testbench's FIFO-driven kernel-write task occupies 129 clock
edges rather than exactly 128 because it includes the FIFO/write alignment
edge.  This is a fixed one-cycle implementation detail; it does not change
the relative conclusion.

For a full input tile with `P = 8`, a macro must issue:

`8 vectors x 32 rows = 256 compute cycles`

When one macro alone handles all eight vectors, its single feature buffer
must be replaced between vectors.  There are seven replacements:

`7 x 4 = 28 feature-load cycles`

Therefore the active-macro processing interval is:

`256 + 28 = 284 cycles`

The last result then needs a small common pipeline/output drain.  It is
excluded from the steady-state comparison below and added only once at the
end of the complete workload.

## Method 1: duplicate the current weights and alternate vectors

Method 1 loads the same current weight tile into both macros.  Macro 0 and
macro 1 then alternate: while one macro computes a vector, the other receives the next vector.

### After the first vector is available, the eight vectors take approximately:

`8 x 32 = 256 compute cycles`

Throughput limitation

At the end of the eight-vector batch, the next weight load is exposed at every tile boundary.  

Per-tile schedule:

`128 weight-load + 4 initial-vector-load + 256 compute = 388 cycles/tile`

## Method 2: ping-pong weight tiles between macros

Method 2 gives one macro ownership of the current weight tile and all eight
input vectors.  While it computes, the inactive macro receives the **next**
weight tile.  At the boundary, the macro roles swap.

The steady-state schedule is:

```text
Macro 0: compute W[i]   x X[i]  for all 8 vectors   (284 cycles)
Macro 1: load    W[i+1]                             (128 cycles)

Macro 1: compute W[i+1] x X[i+1] for all 8 vectors  (284 cycles)
Macro 0: load    W[i+2]                             (128 cycles)
```

The 128-cycle next-weight load fits entirely inside the 284-cycle compute
interval.  It is therefore hidden.  The steady-state cost is:

`max(284 compute-and-feature-load cycles, 128 weight-load cycles)`

`= 284 cycles/tile`

The first tile has a one-time warm-up of approximately:

`128 weight-load + 4 first-vector-load = 132 cycles`

## Cycle comparison

For `N` weight tiles, excluding reset and including a three-cycle final
pipeline drain:

| Number of weight tiles |                 Method 1 |                       Method 2 |
| ---------------------: | -----------------------: | -----------------------------: |
|                     10 | `10 x 388 + 3 = 3,883` | `132 + 10 x 284 + 3 = 2,975` |
|                    100 |               `38,803` |                     `28,535` |
|                    500 |              `194,003` |                    `142,135` |
|                  1,000 |              `388,003` |                    `284,135` |

In steady state, Method 2 requires `284 / 388 = 0.732` times the cycles of
Method 1.  Equivalently, Method 2 provides about **1.37x the throughput**, or
uses about **27% fewer cycles**.

## Implementation in testbench

`tb/tb_double_buffering.sv` implements Method 2:

## Conclusion

**Method 2 is the better double-buffering technique for this two-macro,
shared-FIFO architecture.**

Method 1 hides feature-vector replacement, but it duplicates the current
weights in both macros.  That leaves nowhere to prefetch the next weight tile, so weight loading becomes visible at every transition.  

Method 2 instead uses the inactive macro as a true weight-tile buffer.  Its next-kernel transfer is fully overlapped with the 284-cycle processing of the current tile, which produces the higher sustained throughput.
