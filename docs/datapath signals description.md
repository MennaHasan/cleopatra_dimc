# Datapath signals description

This document describes the current logic in [dimc_datapath.sv](../rtl/dimc_datapath.sv)

## 1. `weight_load`

**What determines its value?**

```systemverilog
weight_load = load_enable && weights_loaded_q < WEIGHT_BEATS && !wgt_empty;
// WEIGHT_BEATS = 128
load_enable = (state_q == LOAD_FIRST) || (state_q == RUN && has_next);
load_macro = (state_q == LOAD_FIRST) ? 1'b0 : ~active_q;
```

weight_load is set cominationally to 1 when loading is enabled, fewer than 128 weight sections have been written into the destination macro, and the weight FIFO contains data. 

**What happens when it is 1?**

- The combinational control drives `wcsn[load_macro] = 0` and `wa[load_macro] = weights_loaded_q[6:0]`. This writes one 256-bit weight section into the macro's internal memory.
- The dual-macro wrapper asserts `wgt_pop`, consuming one 256-bit section from the shared weight FIFO at the edge.
- The destination macro writes that section at row `WA[6:2]`, section `WA[1:0]`, subject to the latched bitwise write mask `mask_q`.
- `weights_loaded_q` increments by one.

In `LOAD_FIRST`, the destination is macro 0. In `RUN`, it is the inactive macro. This signal moves data **from the FIFO into macro memory**; `wgt_push` moves data into the FIFO.

## 2. `first_load`

**Why is this signal needed?**

Control using`first_load` also enables double buffering: it can prepare vector 0 in the **inactive macro** , whereas `feature_load` loads subsequent vectors into the  **active macro** .

**What determines its value?**

```systemverilog
first_load = load_enable && first_sections_q < NUM_SECTIONS && !inp_empty &&
             ((state_q == LOAD_FIRST && inputs_received_q == INPUT_BEATS) ||
              (state_q == RUN && vector_q == 7));
// NUM_SECTIONS = 4; INPUT_BEATS = 32
```

**The first three conditions**

* require loading to be enabled, fewer than four sections of vector 0 to have been loaded, and a nonempty input FIFO.

**The final condition:** 

* When `vector_q` reaches 7, the current tile’s last vector has already been fully loaded into the active macro’s feature buffer. The active macro can compute with that stored vector without taking more input from the FIFO.

**For different states of the FSM**

* In `LOAD_FIRST`, all 32 input sections must have arrived before vector 0 starts loading into macro 0.

- In `RUN`, `vector_q` must be 7. At that point the current tile's last vector is already inside the active macro, so any remaining FIFO data belongs to the next tile. Loading the next tile's vector 0 may begin without waiting for all its 32 sections to arrive.

**What happens when it is 1?**

- The control drives `fcsn[load_macro] = 0` to enables feature-buffer loading and `fa[load_macro] = first_sections_q[1:0]`chooses which of the four buffer sections to fill.
- The wrapper asserts `inp_pop`. At the edge, one 256-bit section leaves the shared input FIFO and is stored in `feature_buf[FA]` of the destination macro.
- `first_sections_q` increments by one. After four transfers, the entire first vector is in that macro and `first_load` becomes 0.

This prepares **vector 0** of the loading tile. Later vectors of the current tile use `feature_load` instead.

## 3. `inp_push`

**What determines its value?**

```systemverilog
input_i.ready = core_rst_n && load_enable &&
                inputs_received_q < INPUT_BEATS && !inp_full;
inp_push = input_i.valid && input_i.ready;
```

It is 1 when the sender presents valid input data and the datapath can accept it: reset/clear is inactive, loading is enabled, fewer than 32 sections have been received for the loading tile, and the input FIFO is not full.

**What happens when it is 1?**

At the edge, the input FIFO stores one 256-bit `input_i.data` beat, and `inputs_received_q` increments. This is the stream's valid/ready handshake. The beat is queued; it reaches a macro's feature buffer only when `first_load` or `feature_load` later requests a pop. Push and pop may also occur in the same cycle.

In `RUN`, incoming sections belong to the next tile and are appended behind any current-tile sections still in the FIFO.

## 4. `wgt_push`

**What determines its value?**

```systemverilog
kernel_i.ready = core_rst_n && load_enable &&
                 weights_received_q < WEIGHT_BEATS && !wgt_full;
wgt_push = kernel_i.valid && kernel_i.ready;
```

It is 1 when the sender presents valid weight data and the datapath can accept it: reset/clear is inactive, loading is enabled, fewer than 128 sections have been received for the loading tile, and the weight FIFO is not full.

**What happens when it is 1?**

At the edge, the weight FIFO stores one 256-bit `kernel_i.data` beat, and `weights_received_q` increments. Writing that section into macro memory is controlled separately by `weight_load`.

`weights_received_q` counts stream-to-FIFO transfers; `weights_loaded_q` counts FIFO-to-macro transfers. Those counts can differ because sections may be waiting in the FIFO. Push and pop can occur in the same cycle.

## 5. `result_pop`

**What determines its value?**

This signal comes from Cleopatra, rather than being calculated in the datapath:

```systemverilog
// Inside cleopatra.sv:
out_pop = ~out_empty;
result_pop_o = out_pop;
// Connected to dimc_datapath.result_pop.
```

It is 1 whenever the shared scalar-result FIFO is nonempty. There is no external receiver-ready condition: Cleopatra automatically drains this FIFO into its accumulators.

The FIFO receives the active macro's pipeline results through the following wrapper logic:

```systemverilog
READYN = m_readyn[sel];  // sel = active_q
PSOUT = m_psout[sel];
out_push = ~READYN & ~out_full;
out_wdata = PSOUT;
```

**What happens when it is 1?**

- One 32-bit scalar result is popped from the output FIFO at the edge.
- The accumulator selected by `acc_sel` adds `out_data` to its stored sum.
- Cleopatra's selector advances to the next accumulator.
- The datapath increments `results_q`, which counts results actually accumulated for the current tile product.

The result order is all 32 rows of vector/column 0, then all 32 rows of column 1, and so on. Accumulator index `c*32+r` therefore maps to `result_o[r][c]`.

`result_pop` transfers **one scalar from the internal FIFO to an accumulator**. The separate `result_valid_o && result_ready_i` handshake accepts **one complete 32×8 accumulated tile** in `PRESENT`. External backpressure holds that completed tile in the accumulators.

## 6. Combinational logic while `state_q == RUN`

The following describes both the continuous assignments and the `always_comb` macro-control block. Unless stated otherwise, `core_rst_n` is 1.

### A. Decide whether to prepare another tile product

```systemverilog
has_next = (l_q != l_size_q-1) ||
           (q_q != q_size_q-1) ||
           (k_q != k_size_q-1);
load_enable = has_next;       // Simplified for RUN
load_macro = ~active_q;       // Simplified for RUN
```

Another tile product exists unless all three indices are at their final values. Traversal advances `l` first, then `q`, then `k`. Even if the current output tile is on its final `l`, the next output tile can be prepared in parallel.

### B. Accept and load data

In `RUN`, the loading and stream equations simplify to:

```systemverilog
input_i.ready = core_rst_n && has_next &&
                inputs_received_q < 32 && !inp_full;
kernel_i.ready = core_rst_n && has_next &&
                 weights_received_q < 128 && !wgt_full;
inp_push = input_i.valid && input_i.ready;
wgt_push = kernel_i.valid && kernel_i.ready;
weight_load = has_next && weights_loaded_q < 128 && !wgt_empty;
first_load = has_next && first_sections_q < 4 && !inp_empty && vector_q == 7;
feature_load = compute_state_q == FEATURES && !inp_empty;
```

`weight_load` and `first_load` target the inactive macro. `feature_load` targets the active macro and loads its next current-tile vector. It does not depend on `has_next`: the final tile product still needs its own remaining vectors.

In normal operation, `first_load` and `feature_load` cannot consume the input FIFO together. `FEATURES` loads the next vector while `vector_q` still identifies the previous vector; after vector 7 has been fully loaded, the FSM returns to `ROWS`, then goes directly to `DRAIN` after its last row.

### C. Set default macro controls, then apply requests

Every evaluation starts with these values for both macros:

```systemverilog
compe = '0;
fcsn = '1;
rcsn = '1;
wcsn = '1;
fa = '0;
ra = '0;
wa = '0;
```

`COMPE` is active high. `FCSN`, `RCSN`, and `WCSN` are active low. The defaults issue no computation, feature load, or weight write. Addresses are zero unless overridden below.

If `core_rst_n` is high, these independent conditions override the defaults:

| Condition during RUN        | Combinational overrides                                                            | Operation requested at the edge                                                      |
| --------------------------- | ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| `weight_load`             | `wcsn[load_macro] = 0`; `wa[load_macro] = weights_loaded_q[6:0]`               | Load one weight section into the inactive macro.                                     |
| `first_load`              | `fcsn[load_macro] = 0`; `fa[load_macro] = first_sections_q[1:0]`               | Load one section of next-tile vector 0 into the inactive macro.                      |
| `compute_state_q == ROWS` | `compe[active_q] = 1`; `rcsn[active_q] = 0`; `ra[active_q] = {row_q, 2'b00}` | Issue one computation using a full weight row and the active macro's feature vector. |
| `feature_load`            | `fcsn[active_q] = 0`; `fa[active_q] = section_q`                               | Load one section of the next current-tile vector into the active macro.              |

The datapath connects each `rcsn` bit to that macro's `RCSN` and `RCSN0..3`, and each `wcsn` bit to `WCSN` and `WEN`. The latched mode, sign, bias, write mask, and compute mask continue to feed both macros.

The three compute substates behave as follows:

- **`ROWS`:** Issue one row command each cycle, 32 commands per vector. The inactive macro may load weights and, when `vector_q == 7`, its first vector concurrently.
- **`FEATURES`:** Issue no compute command. Load one input section per cycle when available; an empty FIFO stalls the feature load. Independent weight loading can continue.
- **`DRAIN`:** Issue no compute command or active-macro feature load. Delayed results continue through the output FIFO into accumulators. Preparation of the inactive macro can continue.

If `core_rst_n` is low, none of the overrides run, stream readiness is low, and reset clears the sequential state and FIFOs.

### D. Check whether the tile-product phase can finish

```systemverilog
next_loaded = weights_loaded_q == 128 &&
              inputs_received_q == 32 && first_sections_q == 4;
phase_complete = compute_state_q == DRAIN && results_q == 256 &&
                 (!has_next || next_loaded);
```

`next_loaded` means all next-tile weights are in the inactive macro, its first input vector is loaded, and all input sections have arrived. The other seven vectors remain queued in the shared input FIFO.

`phase_complete` requires all 256 current results to have been accumulated. If another tile product exists, it must also be prepared before this phase ends. On the final tile product, there is no next-tile loading requirement.

These are combinational decisions. At the subsequent clock edge, the sequential `RUN` logic enters `PRESENT` if `l_q == l_size_q-1`, or `ADVANCE` otherwise. The macro selection changes later in `ADVANCE`, after the current results have drained.

### E. Other combinational values during RUN

- `ready_o = core_rst_n`: the accepted job remains active, including during `DRAIN`. This does not mean the individual streams can accept a beat.
- `result_valid_o = 0`: external tile acceptance is enabled only in `PRESENT`.
- `acc_clear = 0`: partial sums are preserved during computation and across the contributing `l` tile products.
- `result_o[r][c] = acc[c*32+r]`: outputs continuously expose accumulator contents, but they are not a valid completed tile while `result_valid_o` is 0.
- `result_pop` continues to follow Cleopatra's output-FIFO nonempty status, independently of the compute substate.
- `valid_config` still evaluates the live dimension and mode inputs: nonzero weight rows/columns and input columns, equal weight columns/input rows, dimensions divisible by 32/128/8 respectively, and `mode_i == 2'b11`. It is only used to accept a start in `IDLE`; it does not alter the running job, whose configuration is latched.

`done_o`, the state registers, tile indices, loading counters, and compute counters are sequential signals. Combinational decisions do not update them immediately. In particular, the edge that accumulates result 256 updates `results_q`; only after that update can the comparison `results_q == 256` become true.

## 7. `load_enable`

**What determines its value?**

```systemverilog
load_enable = (state_q == LOAD_FIRST) || (state_q == RUN && has_next);

has_next = (l_q != l_size_q-1) ||
           (q_q != q_size_q-1) ||
           (k_q != k_size_q-1);
```

Its direct inputs are `state_q` and `has_next`. In turn, `has_next` depends on the current tile indices (`l_q`, `q_q`, `k_q`) and the latched tile counts (`l_size_q`, `q_size_q`, `k_size_q`).


`has_next` means another tile product remains after the current one.

| Current state                                         | `load_enable` | Reason                                                                                |
| ----------------------------------------------------- | --------------- | ------------------------------------------------------------------------------------- |
| `LOAD_FIRST`                                        | 1               | Prepare the first tile product in macro 0, even for a job with only one tile product. |
| `RUN`, with `has_next == 1`                       | 1               | Prepare the next tile product in the inactive macro while the current one runs.       |
| `RUN`, with `has_next == 0`                       | 0               | The current tile product is the final one; there is no next tile to load.             |
| `IDLE`, `PRESENT`, `CLEAR_TILE`, or `ADVANCE` | 0               | No new tile loading is enabled in these states.                                       |

**What happens when it is 1?**

It permits the loading path to operate, subject to the other conditions:

- `input_i.ready` can become 1 if reset/clear is inactive, fewer than 32 input sections have arrived, and the input FIFO is not full. A transfer still requires `input_i.valid`.
- `kernel_i.ready` can become 1 if reset/clear is inactive, fewer than 128 weight sections have arrived, and the weight FIFO is not full. A transfer still requires `kernel_i.valid`.
- `weight_load` can become 1 if fewer than 128 weight sections have been loaded and the weight FIFO is nonempty.
- `first_load` can become 1 if its section-count, FIFO-data, and FIFO-ownership conditions are satisfied, as described in section 2.

A high `load_enable` does not itself push or pop a FIFO, write a macro, or increment a counter. It allows those operations when their remaining conditions are met. The destination is macro 0 in `LOAD_FIRST`, or `~active_q` in `RUN`.

**What happens when it is 0?**

It forces `input_i.ready`, `kernel_i.ready`, `inp_push`, `wgt_push`, `weight_load`, and `first_load` to 0. Therefore, no new stream beats are accepted, no weight sections are transferred into a macro, and no loading-tile first-vector sections are transferred into a macro through `first_load`.

It does **not** flush FIFOs, clear accumulators, or stop the current computation. During the final tile product in `RUN`:

- `ROWS` can still issue compute commands.
- `feature_load` can still move the current tile's remaining vectors from the input FIFO into the active macro, because it does not depend on `load_enable`.
- Pipeline results can still enter the output FIFO, and `result_pop` can still drain them into accumulators.

Likewise, a completed tile can still be accepted in `PRESENT` while `load_enable` is 0. Loading permission and external result acceptance are separate controls.
