# This script was generated automatically by bender.
set ROOT "/srv/home/mennatalla.hassan/cleopatra_dimc"

if {[catch { vlog -incr -sv \
    -sv \
    -timescale 1ns/1ps \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TB" \
    "+define+TARGET_VSIM" \
    "$ROOT/.bender/git/checkouts/common_verification-a8b72de09c195e68/src/clk_rst_gen.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-a8b72de09c195e68/src/sim_timeout.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-a8b72de09c195e68/src/stream_watchdog.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-a8b72de09c195e68/src/signal_highlighter.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -sv \
    -timescale 1ns/1ps \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TB" \
    "+define+TARGET_VSIM" \
    "$ROOT/.bender/git/checkouts/common_verification-a8b72de09c195e68/src/rand_id_queue.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-a8b72de09c195e68/src/rand_stream_mst.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-a8b72de09c195e68/src/rand_synch_holdable_driver.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-a8b72de09c195e68/src/rand_verif_pkg.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-a8b72de09c195e68/src/rand_synch_driver.sv" \
    "$ROOT/.bender/git/checkouts/common_verification-a8b72de09c195e68/src/rand_stream_slv.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -sv \
    -timescale 1ns/1ps \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TB" \
    "+define+TARGET_VSIM" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-10954772e29dbc2a/src/rtl/tc_sram.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-10954772e29dbc2a/src/rtl/tc_sram_impl.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -sv \
    -timescale 1ns/1ps \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TB" \
    "+define+TARGET_VSIM" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-10954772e29dbc2a/src/rtl/tc_clk.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -sv \
    -timescale 1ns/1ps \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TB" \
    "+define+TARGET_VSIM" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-10954772e29dbc2a/src/rtl/tc_sync.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -sv \
    -timescale 1ns/1ps \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TB" \
    "+define+TARGET_VSIM" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-10954772e29dbc2a/src/deprecated/cluster_pwr_cells.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-10954772e29dbc2a/src/deprecated/generic_memory.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-10954772e29dbc2a/src/deprecated/generic_rom.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-10954772e29dbc2a/src/deprecated/pad_functional.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-10954772e29dbc2a/src/deprecated/pulp_buffer.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-10954772e29dbc2a/src/deprecated/pulp_pwr_cells.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -sv \
    -timescale 1ns/1ps \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TB" \
    "+define+TARGET_VSIM" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-10954772e29dbc2a/src/tc_pwr.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -sv \
    -timescale 1ns/1ps \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TB" \
    "+define+TARGET_VSIM" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-10954772e29dbc2a/src/deprecated/pulp_clock_gating_async.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-10954772e29dbc2a/src/deprecated/cluster_clk_cells.sv" \
    "$ROOT/.bender/git/checkouts/tech_cells_generic-10954772e29dbc2a/src/deprecated/pulp_clk_cells.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -sv \
    -timescale 1ns/1ps \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TB" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/include" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/binary_to_gray.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -sv \
    -timescale 1ns/1ps \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TB" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/include" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/cb_filter_pkg.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/cc_onehot.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/cdc_reset_ctrlr_pkg.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/cf_math_pkg.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/clk_int_div.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/credit_counter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/delta_counter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/ecc_pkg.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/edge_propagator_tx.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/exp_backoff.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/fifo_v3.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/gray_to_binary.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/heaviside.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/isochronous_4phase_handshake.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/isochronous_spill_register.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/lfsr.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/lfsr_16bit.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/lfsr_8bit.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/lossy_valid_to_stream.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/mv_filter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/onehot_to_bin.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/plru_tree.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/passthrough_stream_fifo.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/popcount.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/ring_buffer.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/rr_arb_tree.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/rstgen_bypass.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/serial_deglitch.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/shift_reg.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/shift_reg_gated.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/spill_register_flushable.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/stream_demux.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/stream_filter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/stream_fork.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/stream_intf.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/stream_join_dynamic.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/stream_mux.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/stream_throttle.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/sub_per_hash.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/sync.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/sync_wedge.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/unread.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/read.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/addr_decode_dync.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/boxcar.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/cdc_2phase.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/cdc_4phase.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/clk_int_div_static.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/trip_counter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/addr_decode.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/addr_decode_napot.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/multiaddr_decode.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -sv \
    -timescale 1ns/1ps \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TB" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/include" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/cb_filter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/cdc_fifo_2phase.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/clk_mux_glitch_free.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/counter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/ecc_decode.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/ecc_encode.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/edge_detect.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/lzc.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/max_counter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/rstgen.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/spill_register.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/stream_delay.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/stream_fifo.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/stream_fork_dynamic.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/stream_join.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/cdc_reset_ctrlr.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/cdc_fifo_gray.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/fall_through_register.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/id_queue.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/stream_to_mem.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/stream_arbiter_flushable.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/stream_fifo_optimal_wrap.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/stream_register.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/stream_xbar.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/cdc_fifo_gray_clearable.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/cdc_2phase_clearable.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/mem_to_banks_detailed.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/stream_arbiter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/stream_omega_net.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/mem_to_banks.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -sv \
    -timescale 1ns/1ps \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TB" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/include" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/deprecated/sram.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -sv \
    -timescale 1ns/1ps \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TB" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/include" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/deprecated/clock_divider_counter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/deprecated/clk_div.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/deprecated/find_first_one.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/deprecated/generic_LFSR_8bit.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/deprecated/generic_fifo.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/deprecated/prioarbiter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/deprecated/pulp_sync.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/deprecated/pulp_sync_wedge.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/deprecated/rrarbiter.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/deprecated/clock_divider.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/deprecated/fifo_v2.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/deprecated/fifo_v1.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/edge_propagator_ack.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/edge_propagator.sv" \
    "$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/src/edge_propagator_rx.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -sv \
    -timescale 1ns/1ps \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TB" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/apb-26934b3447381e5f/include" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/include" \
    "$ROOT/.bender/git/checkouts/apb-26934b3447381e5f/src/apb_pkg.sv" \
    "$ROOT/.bender/git/checkouts/apb-26934b3447381e5f/src/apb_intf.sv" \
    "$ROOT/.bender/git/checkouts/apb-26934b3447381e5f/src/apb_err_slv.sv" \
    "$ROOT/.bender/git/checkouts/apb-26934b3447381e5f/src/apb_regs.sv" \
    "$ROOT/.bender/git/checkouts/apb-26934b3447381e5f/src/apb_cdc.sv" \
    "$ROOT/.bender/git/checkouts/apb-26934b3447381e5f/src/apb_demux.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -sv \
    -timescale 1ns/1ps \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TB" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/apb-26934b3447381e5f/include" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/include" \
    "$ROOT/.bender/git/checkouts/apb-26934b3447381e5f/src/apb_test.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -sv \
    -timescale 1ns/1ps \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TB" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/include" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/include" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_pkg.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_intf.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_atop_filter.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_burst_splitter.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_cdc_dst.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_cdc_src.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_cut.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_delayer.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_demux.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_dw_downsizer.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_dw_upsizer.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_fifo.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_id_remap.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_id_prepend.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_isolate.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_join.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_lite_demux.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_lite_join.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_lite_lfsr.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_lite_mailbox.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_lite_mux.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_lite_regs.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_lite_to_apb.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_lite_to_axi.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_modify_address.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_mux.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_serializer.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_throttle.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_to_mem.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_cdc.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_err_slv.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_dw_converter.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_id_serialize.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_lfsr.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_multicut.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_to_axi_lite.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_to_mem_banked.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_to_mem_interleaved.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_to_mem_split.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_iw_converter.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_lite_xbar.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_xbar.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_xp.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -sv \
    -timescale 1ns/1ps \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TB" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/include" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/include" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_dumper.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_sim_mem.sv" \
    "$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/src/axi_test.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -sv \
    -timescale 1ns/1ps \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TB" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/apb-26934b3447381e5f/include" \
    "+incdir+$ROOT/.bender/git/checkouts/axi-a498e2b14ce12361/include" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/include" \
    "+incdir+$ROOT/.bender/git/checkouts/register_interface-582bfe04e82345d4/include" \
    "$ROOT/.bender/git/checkouts/register_interface-582bfe04e82345d4/src/reg_intf.sv" \
    "$ROOT/.bender/git/checkouts/register_interface-582bfe04e82345d4/vendor/lowrisc_opentitan/src/prim_subreg_arb.sv" \
    "$ROOT/.bender/git/checkouts/register_interface-582bfe04e82345d4/vendor/lowrisc_opentitan/src/prim_subreg_ext.sv" \
    "$ROOT/.bender/git/checkouts/register_interface-582bfe04e82345d4/src/apb_to_reg.sv" \
    "$ROOT/.bender/git/checkouts/register_interface-582bfe04e82345d4/src/axi_to_reg.sv" \
    "$ROOT/.bender/git/checkouts/register_interface-582bfe04e82345d4/src/periph_to_reg.sv" \
    "$ROOT/.bender/git/checkouts/register_interface-582bfe04e82345d4/src/reg_cdc.sv" \
    "$ROOT/.bender/git/checkouts/register_interface-582bfe04e82345d4/src/reg_demux.sv" \
    "$ROOT/.bender/git/checkouts/register_interface-582bfe04e82345d4/src/reg_err_slv.sv" \
    "$ROOT/.bender/git/checkouts/register_interface-582bfe04e82345d4/src/reg_mux.sv" \
    "$ROOT/.bender/git/checkouts/register_interface-582bfe04e82345d4/src/reg_to_apb.sv" \
    "$ROOT/.bender/git/checkouts/register_interface-582bfe04e82345d4/src/reg_to_mem.sv" \
    "$ROOT/.bender/git/checkouts/register_interface-582bfe04e82345d4/src/reg_uniform.sv" \
    "$ROOT/.bender/git/checkouts/register_interface-582bfe04e82345d4/src/reg_to_tlul.sv" \
    "$ROOT/.bender/git/checkouts/register_interface-582bfe04e82345d4/vendor/lowrisc_opentitan/src/prim_subreg_shadow.sv" \
    "$ROOT/.bender/git/checkouts/register_interface-582bfe04e82345d4/vendor/lowrisc_opentitan/src/prim_subreg.sv" \
    "$ROOT/.bender/git/checkouts/register_interface-582bfe04e82345d4/src/axi_lite_to_reg.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -sv \
    -timescale 1ns/1ps \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TB" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/low_latency_interco" \
    "+incdir+$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/peripheral_interco" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/include" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/tcdm_interconnect/tcdm_interconnect_pkg.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/tcdm_interconnect/addr_dec_resp_mux.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/tcdm_interconnect/amo_shim.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/variable_latency_interconnect/addr_decoder.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/tcdm_interconnect/xbar.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/variable_latency_interconnect/simplex_xbar.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/tcdm_interconnect/clos_net.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/tcdm_interconnect/bfly_net.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/variable_latency_interconnect/full_duplex_xbar.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/tcdm_interconnect/tcdm_interconnect.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/variable_latency_interconnect/variable_latency_bfly_net.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/variable_latency_interconnect/variable_latency_interconnect.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/low_latency_interco/FanInPrimitive_Req.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/low_latency_interco/ArbitrationTree.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/low_latency_interco/MUX2_REQ.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/low_latency_interco/AddressDecoder_Resp.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/low_latency_interco/TestAndSet.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/low_latency_interco/RequestBlock2CH.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/low_latency_interco/RequestBlock1CH.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/low_latency_interco/FanInPrimitive_Resp.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/low_latency_interco/ResponseTree.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/low_latency_interco/ResponseBlock.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/low_latency_interco/AddressDecoder_Req.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/low_latency_interco/XBAR_TCDM.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/low_latency_interco/XBAR_TCDM_WRAPPER.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/low_latency_interco/TCDM_PIPE_REQ.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/low_latency_interco/TCDM_PIPE_RESP.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/low_latency_interco/grant_mask.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/low_latency_interco/priority_Flag_Req.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/peripheral_interco/AddressDecoder_PE_Req.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/peripheral_interco/AddressDecoder_Resp_PE.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/peripheral_interco/ArbitrationTree_PE.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/peripheral_interco/FanInPrimitive_Req_PE.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/peripheral_interco/RR_Flag_Req_PE.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/peripheral_interco/MUX2_REQ_PE.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/peripheral_interco/FanInPrimitive_PE_Resp.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/peripheral_interco/RequestBlock1CH_PE.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/peripheral_interco/RequestBlock2CH_PE.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/peripheral_interco/ResponseBlock_PE.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/peripheral_interco/ResponseTree_PE.sv" \
    "$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/peripheral_interco/XBAR_PE.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -sv \
    -timescale 1ns/1ps \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TB" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/hwpe_stream_package.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/hwpe_stream_interfaces.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/basic/hwpe_stream_assign.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/basic/hwpe_stream_buffer.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/basic/hwpe_stream_demux_static.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/basic/hwpe_stream_deserialize.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/basic/hwpe_stream_fence.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/basic/hwpe_stream_fence_asymmetric.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/basic/hwpe_stream_merge.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/basic/hwpe_stream_mux_static.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/basic/hwpe_stream_serialize.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/basic/hwpe_stream_split.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/fifo/hwpe_stream_fifo_ctrl.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/fifo/hwpe_stream_fifo_scm.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/streamer/hwpe_stream_addressgen.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/streamer/hwpe_stream_addressgen_v2.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/streamer/hwpe_stream_addressgen_v3.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/streamer/hwpe_stream_addressgen_v4.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/streamer/hwpe_stream_sink_realign.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/streamer/hwpe_stream_source_realign.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/streamer/hwpe_stream_strbgen.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/streamer/hwpe_stream_streamer_queue.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/tcdm/hwpe_stream_tcdm_assign.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/tcdm/hwpe_stream_tcdm_mux.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/tcdm/hwpe_stream_tcdm_mux_static.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/tcdm/hwpe_stream_tcdm_reorder.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/tcdm/hwpe_stream_tcdm_reorder_static.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/fifo/hwpe_stream_fifo_earlystall.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/fifo/hwpe_stream_fifo_earlystall_sidech.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/fifo/hwpe_stream_fifo_scm_test_wrap.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/fifo/hwpe_stream_fifo_sidech.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/fifo/hwpe_stream_fifo.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/tcdm/hwpe_stream_tcdm_fifo_load_sidech.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/fifo/hwpe_stream_fifo_passthrough.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/streamer/hwpe_stream_source.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/tcdm/hwpe_stream_tcdm_fifo.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/tcdm/hwpe_stream_tcdm_fifo_load.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/tcdm/hwpe_stream_tcdm_fifo_store.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-stream-3b54439c7a702cf7/rtl/streamer/hwpe_stream_sink.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -sv \
    -timescale 1ns/1ps \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TB" \
    "+define+TARGET_VSIM" \
    "$ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-ff7ca39a6b865d85/RTL/l2_tcdm_demux.sv" \
    "$ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-ff7ca39a6b865d85/RTL/lint_2_apb.sv" \
    "$ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-ff7ca39a6b865d85/RTL/lint_2_axi.sv" \
    "$ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-ff7ca39a6b865d85/RTL/axi_2_lint/axi64_2_lint32.sv" \
    "$ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-ff7ca39a6b865d85/RTL/axi_2_lint/axi_read_ctrl.sv" \
    "$ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-ff7ca39a6b865d85/RTL/axi_2_lint/axi_write_ctrl.sv" \
    "$ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-ff7ca39a6b865d85/RTL/axi_2_lint/lint64_to_32.sv" \
    "$ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-ff7ca39a6b865d85/RTL/XBAR_L2/AddressDecoder_Req_L2.sv" \
    "$ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-ff7ca39a6b865d85/RTL/XBAR_L2/AddressDecoder_Resp_L2.sv" \
    "$ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-ff7ca39a6b865d85/RTL/XBAR_L2/ArbitrationTree_L2.sv" \
    "$ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-ff7ca39a6b865d85/RTL/XBAR_L2/FanInPrimitive_Req_L2.sv" \
    "$ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-ff7ca39a6b865d85/RTL/XBAR_L2/FanInPrimitive_Resp_L2.sv" \
    "$ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-ff7ca39a6b865d85/RTL/XBAR_L2/MUX2_REQ_L2.sv" \
    "$ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-ff7ca39a6b865d85/RTL/XBAR_L2/RequestBlock_L2_1CH.sv" \
    "$ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-ff7ca39a6b865d85/RTL/XBAR_L2/RequestBlock_L2_2CH.sv" \
    "$ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-ff7ca39a6b865d85/RTL/XBAR_L2/ResponseBlock_L2.sv" \
    "$ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-ff7ca39a6b865d85/RTL/XBAR_L2/ResponseTree_L2.sv" \
    "$ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-ff7ca39a6b865d85/RTL/XBAR_L2/RR_Flag_Req_L2.sv" \
    "$ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-ff7ca39a6b865d85/RTL/XBAR_L2/XBAR_L2.sv" \
    "$ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-ff7ca39a6b865d85/RTL/XBAR_BRIDGE/AddressDecoder_Req_BRIDGE.sv" \
    "$ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-ff7ca39a6b865d85/RTL/XBAR_BRIDGE/AddressDecoder_Resp_BRIDGE.sv" \
    "$ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-ff7ca39a6b865d85/RTL/XBAR_BRIDGE/ArbitrationTree_BRIDGE.sv" \
    "$ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-ff7ca39a6b865d85/RTL/XBAR_BRIDGE/FanInPrimitive_Req_BRIDGE.sv" \
    "$ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-ff7ca39a6b865d85/RTL/XBAR_BRIDGE/FanInPrimitive_Resp_BRIDGE.sv" \
    "$ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-ff7ca39a6b865d85/RTL/XBAR_BRIDGE/MUX2_REQ_BRIDGE.sv" \
    "$ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-ff7ca39a6b865d85/RTL/XBAR_BRIDGE/RequestBlock1CH_BRIDGE.sv" \
    "$ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-ff7ca39a6b865d85/RTL/XBAR_BRIDGE/RequestBlock2CH_BRIDGE.sv" \
    "$ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-ff7ca39a6b865d85/RTL/XBAR_BRIDGE/ResponseBlock_BRIDGE.sv" \
    "$ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-ff7ca39a6b865d85/RTL/XBAR_BRIDGE/ResponseTree_BRIDGE.sv" \
    "$ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-ff7ca39a6b865d85/RTL/XBAR_BRIDGE/RR_Flag_Req_BRIDGE.sv" \
    "$ROOT/.bender/git/checkouts/l2_tcdm_hybrid_interco-ff7ca39a6b865d85/RTL/XBAR_BRIDGE/XBAR_BRIDGE.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -sv \
    -timescale 1ns/1ps \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TB" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/include" \
    "+incdir+$ROOT/.bender/git/checkouts/register_interface-582bfe04e82345d4/include" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/ODRG_unit/odrg_manager_reg_pkg.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/ecc_wrap/ecc_manager_reg_pkg.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/pulpissimo_tcls/tcls_manager_reg_pkg.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/lowrisc_ecc/prim_secded_13_8_cor.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/lowrisc_ecc/prim_secded_13_8_dec.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/lowrisc_ecc/prim_secded_13_8_enc.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/lowrisc_ecc/prim_secded_22_16_cor.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/lowrisc_ecc/prim_secded_22_16_dec.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/lowrisc_ecc/prim_secded_22_16_enc.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/lowrisc_ecc/prim_secded_39_32_cor.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/lowrisc_ecc/prim_secded_39_32_dec.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/lowrisc_ecc/prim_secded_39_32_enc.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/lowrisc_ecc/prim_secded_72_64_cor.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/lowrisc_ecc/prim_secded_72_64_dec.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/lowrisc_ecc/prim_secded_72_64_enc.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/lowrisc_ecc/prim_secded_pkg.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/ODRG_unit/triple_core_barrier.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/hsiao_ecc/hsiao_ecc_pkg.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/hsiao_ecc/hsiao_ecc_enc.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/hsiao_ecc/hsiao_ecc_dec.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/hsiao_ecc/hsiao_ecc_cor.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/TMR_voter.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/TMR_word_voter.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/HMR/resp_suppress.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/ODRG_unit/odrg_manager_reg_top.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/ecc_wrap/ecc_manager_reg_top.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/pulpissimo_tcls/tcls_manager_reg_top.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/ecc_wrap/ecc_scrubber.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/TMR_voter_detect.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/bitwise_TMR_voter.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/ecc_wrap/ecc_manager.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/ecc_wrap/ecc_sram_wrap.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -sv \
    -timescale 1ns/1ps \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TB" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/include" \
    "+incdir+$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/ODRG_unit" \
    "+incdir+$ROOT/.bender/git/checkouts/register_interface-582bfe04e82345d4/include" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/ODRG_unit/ODRG_unit.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -sv \
    -timescale 1ns/1ps \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TB" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/include" \
    "+incdir+$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/pulpissimo_tcls" \
    "+incdir+$ROOT/.bender/git/checkouts/register_interface-582bfe04e82345d4/include" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/pulpissimo_tcls/TCLS_unit.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -sv \
    -timescale 1ns/1ps \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TB" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/include" \
    "+incdir+$ROOT/.bender/git/checkouts/register_interface-582bfe04e82345d4/include" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/HMR/rapid_recovery_pkg.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/HMR/recovery_csr.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/HMR/recovery_pc.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/HMR/recovery_rf.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/HMR/rapid_recovery_unit.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/HMR/DMR_checker.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/HMR/DMR_CSR_checker.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/HMR/DMR_address_generator.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/HMR/hmr_rapid_recovery_ctrl.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/HMR/hmr_registers_reg_pkg.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/HMR/hmr_core_regs_reg_pkg.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/HMR/hmr_dmr_regs_reg_pkg.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/HMR/hmr_tmr_regs_reg_pkg.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/HMR/hmr_registers_reg_top.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/HMR/hmr_core_regs_reg_top.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/HMR/hmr_dmr_regs_reg_top.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/HMR/hmr_dmr_ctrl.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/HMR/hmr_tmr_regs_reg_top.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/HMR/hmr_tmr_ctrl.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/HMR/HMR_wrap.sv" \
    "$ROOT/.bender/git/checkouts/redundancy_cells-63b80e1a67a04b12/rtl/HMR/hmr_unit.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -sv \
    -timescale 1ns/1ps \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TB" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/low_latency_interco" \
    "+incdir+$ROOT/.bender/git/checkouts/cluster_interconnect-d4f5a63cdd49d7bf/rtl/peripheral_interco" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/include" \
    "+incdir+$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/common" \
    "+incdir+$ROOT/.bender/git/checkouts/register_interface-582bfe04e82345d4/include" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/common/hci_package.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/ecc/hci_ecc_manager_reg_pkg.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/common/hci_interfaces.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/ecc/hci_ecc_manager_reg_top.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/core/hci_core_assign.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/core/hci_core_assign_expand.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/core/hci_core_cut.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/core/hci_core_fifo.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/core/hci_core_mux_dynamic.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/core/hci_core_mux_static.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/core/hci_core_mux_ooo.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/core/hci_core_r_valid_filter.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/core/hci_core_r_id_filter.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/core/hci_core_rob.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/core/hci_core_source.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/core/hci_core_source_v2.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/core/hci_core_split.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/ecc/hci_ecc_dec.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/ecc/hci_ecc_enc.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/ecc/hci_ecc_manager.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/variablelatency/hci_variablelatency_assign.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/variablelatency/hci_variablelatency_tocore.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/interco/hci_log_interconnect.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/interco/deprecated/hci_log_interconnect_l2.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/interco/hci_new_log_interconnect.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/interco/hci_arbiter.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/interco/hci_arbiter_tree.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/interco/hci_router_reorder.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/parity/hci_copy_source.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/parity/hci_copy_sink.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/core/hci_core_sink.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/ecc/hci_ecc_source.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/core/hci_core_sink_v2.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/interco/hci_router.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/ecc/hci_ecc_interconnect.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/ecc/hci_ecc_sink.sv" \
    "$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/hci_interconnect.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -sv \
    -timescale 1ns/1ps \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TB" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/include" \
    "+incdir+$ROOT/.bender/git/checkouts/hwpe-ctrl-5b325d8bc8491242/rtl" \
    "+incdir+$ROOT/.bender/git/checkouts/hwpe-ctrl-5b325d8bc8491242/rtl/include" \
    "$ROOT/.bender/git/checkouts/hwpe-ctrl-5b325d8bc8491242/rtl/hwpe_ctrl_package.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-ctrl-5b325d8bc8491242/rtl/hwpe_ctrl_interfaces.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-ctrl-5b325d8bc8491242/rtl/deprecated/hwpe_ctrl_regfile_ff.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-ctrl-5b325d8bc8491242/rtl/deprecated/hwpe_ctrl_regfile_latch.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-ctrl-5b325d8bc8491242/rtl/hwpe_ctrl_seq_mult.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-ctrl-5b325d8bc8491242/rtl/hwpe_ctrl_partial_mult.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-ctrl-5b325d8bc8491242/rtl/hwpe_ctrl_uloop.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-ctrl-5b325d8bc8491242/rtl/hwpe_ctrl_target.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-ctrl-5b325d8bc8491242/rtl/deprecated/hwpe_ctrl_regfile_latch_test_wrap.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-ctrl-5b325d8bc8491242/rtl/deprecated/hwpe_ctrl_regfile.sv" \
    "$ROOT/.bender/git/checkouts/hwpe-ctrl-5b325d8bc8491242/rtl/deprecated/hwpe_ctrl_slave.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -sv \
    -timescale 1ns/1ps \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TB" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/include" \
    "+incdir+$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/common" \
    "+incdir+$ROOT/.bender/git/checkouts/hwpe-ctrl-5b325d8bc8491242/rtl/include" \
    "$ROOT/rtl/spatz_dimc.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -sv \
    -timescale 1ns/1ps \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TB" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/include" \
    "+incdir+$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/common" \
    "+incdir+$ROOT/.bender/git/checkouts/hwpe-ctrl-5b325d8bc8491242/rtl/include" \
    "$ROOT/rtl/spatz_dimc_dual.sv" \
    "$ROOT/rtl/dimc_package.sv" \
    "$ROOT/rtl/dimc_datapath.sv" \
    "$ROOT/rtl/dimc_hci_mux.sv" \
    "$ROOT/rtl/dimc_streamer.sv" \
    "$ROOT/rtl/dimc_ctrl.sv" \
    "$ROOT/rtl/dimc_module.sv" \
    "$ROOT/rtl/dimc_top.sv" \
    "$ROOT/rtl/accumulator.sv" \
    "$ROOT/rtl/cleopatra_ctrl.sv" \
    "$ROOT/rtl/cleopatra.sv" \
}]} {return 1}

if {[catch { vlog -incr -sv \
    -sv \
    -timescale 1ns/1ps \
    "+define+TARGET_SIMULATION" \
    "+define+TARGET_TB" \
    "+define+TARGET_VSIM" \
    "+incdir+$ROOT/.bender/git/checkouts/common_cells-08441e68e45d61c0/include" \
    "+incdir+$ROOT/.bender/git/checkouts/hci-49bf0cda3c8e3e73/rtl/common" \
    "+incdir+$ROOT/.bender/git/checkouts/hwpe-ctrl-5b325d8bc8491242/rtl/include" \
    "$ROOT/tb/tb_dimc_dual.sv" \
    "$ROOT/tb/tb_double_buffering.sv" \
    "$ROOT/tb/tb_spatz_dimc.sv" \
    "$ROOT/tb/tb_dimc_datapath.sv" \
    "$ROOT/tb/tb_dimc_test1_timing.sv" \
    "$ROOT/tb/tb_dimc_top.sv" \
    "$ROOT/tb/tb_cleopatra.sv" \
}]} {return 1}

