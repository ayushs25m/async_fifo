# # Dual-Clock Asynchronous FIFO

A Gray-code, dual-flop-synchronizer asynchronous FIFO implementation in Verilog,
based on Clifford E. Cummings' SNUG 2002 papers (Sunburst Design):
*"Simulation and Synthesis Techniques for Asynchronous FIFO Design"* (FIFO1) and
*"...Part 2"* (FIFO2). This implementation follows the FIFO1 architecture:
Gray-coded read/write pointers, 2-flip-flop synchronizers crossing each clock
domain, and registered full/empty flags computed from a look-ahead pointer
comparison.

Developed as part of an MTP (Master's Thesis Project) BCI speech decoder
pipeline, where this FIFO sits between an asynchronous spike-detector IC and
the neural decoder's clock domain, and doubles as VLSI/RTL interview
preparation material.

## Architecture

| Module | Role |
|---|---|
| `asyncfifo` | Top-level - wires all submodules together |
| `asyncfifo_mem` | Dual-port memory array, single-clock write, combinational read |
| `sync_r2w` | 2-flop synchronizer: read pointer → write clock domain |
| `sync_w2r` | 2-flop synchronizer: write pointer → read clock domain |
| `full_flag` | Write-domain pointer logic + registered `w_full` (look-ahead comparison, MSB-inverted against the synced read pointer) |
| `empty_flag` | Read-domain pointer logic + registered `r_empty` (direct comparison against the synced write pointer) |

**Key design points:**
- Both read and write pointers are `ADDR_SIZE+1` bits wide - the extra MSB
  disambiguates a full FIFO from an empty one after pointer wraparound.
- Only the Gray-coded pointer crosses clock domains (via the 2-flop
  synchronizers); the binary pointer stays local to its own domain and drives
  the memory address directly, since same-domain addressing needs no CDC
  protection and no Gray-code latency cost.
- Both flags are **registered**, one cycle after their combinational
  `_val` signal, which is intentional: the address and the flag that gates
  writes/reads into memory are always evaluated against the *same* prior-cycle
  state, so there is no race between "the pointer has moved" and "the flag
  says it's safe to move."
- The look-ahead comparison (comparing `w_graynext`/`r_graynext` - the
  pointer's *next* value - rather than the current pointer) exists specifically
  to cancel out the one-cycle latency introduced by registering the flag. This
  is the load-bearing trick that makes the whole design safe against
  overflow/underflow at any clock ratio.
- Both flags are deliberately **pessimistic**: the synchronizer lag means the
  write side always sees a *stale, lagging* read pointer (and vice versa),
  which means each side always under-estimates how much room/data is actually
  available - never over-estimates. This costs a small amount of usable
  throughput near the boundaries but never costs correctness.

## Bug found and fixed during review

The original top-level `asyncfifo` module had `asyncfifo_mem`'s `w_en` port
left dangling (undeclared at the top level, since the actual port list uses
`w_incr`/`r_incr`), making it a permanently-`x` implicit wire. This silently
disabled all memory writes in simulation. Fixed by connecting `.w_en(w_incr)`
at the top level, matching Cummings' original `fifo1.v` wiring.

## Test suite

Eight independent stress-test cases target the corner conditions most likely
to expose asynchronous-FIFO bugs, plus one combined testbench running all
eight sequentially.

| File | Case | What it checks |
|---|---|---|
| `tb_case1_full_concurrent.v` | 1 | Simultaneous read+write at FULL - no overflow, `w_full` deasserts only after real synchronizer latency |
| `tb_case2_empty_concurrent.v` | 2 | Simultaneous read+write at EMPTY - bogus read while `r_empty=1` doesn't corrupt the pointer or eat the real write |
| `tb_case3_wraparound.v` | 3 | Full → empty → full ×4 - Gray-code pointer wraparound past all-1s→0, repeatedly |
| `tb_case4_reset_midtransfer.v` | 4 | Reset asserted mid-write, both domains - clean recovery, no stale synchronizer garbage |
| `tb_case5_asymmetric_reset.v` | 5 | Only `w_rstn` toggles, `r_rstn` stays high - un-reset domain never glitches to X |
| `tb_case6_extreme_clock_ratio.v` | 6 | 25:1 clock ratio, both directions - correctness holds regardless of speed mismatch |
| `tb_case7_maxrate_writes.v` | 7 | `w_incr` held high every cycle, no idle gaps, past FIFO depth - no off-by-one, excess writes cleanly rejected |
| `tb_case8_single_entry.v` | 8 | Minimum-occupancy boundary - write/read exactly one word, tightest margin for empty-flag off-by-ones |
| `tb_asyncfifo_all_cases.v` | **all 8** | Combined suite, run sequentially in one file |

All cases pass with 0 errors as of the final combined run.

### Testbench timing lessons (worth knowing before extending this suite)

Several non-obvious Verilog scheduling issues surfaced while building these
tests, all fixed in the final versions:

1. **Nonblocking assignment, always** - any signal driving a DUT input that's
   also sampled by another process on the same edge (the DUT itself, or a
   scoreboard monitor) must be driven with `<=`, never `=`. Blocking
   assignments have no guaranteed ordering relative to other processes
   triggered by the same clock edge.
2. **Check reads *before* popping, not after** - `r_data` is valid for the
   *current* front-of-queue item before `r_incr` advances the pointer at the
   next edge. Checking after the pop reads one item ahead of what you meant
   to check.
3. **Priming burst writes** - when holding `w_incr` high across many cycles,
   `w_data` must be primed with its *first* intended value *before* the burst
   loop's first clock edge - otherwise the first accepted write silently uses
   whatever stale value `w_data` was last left holding (visible as data
   corruption when running multiple test cases back-to-back in one file).
4. **Scoreboard writes via a same-clock monitor for oversubscribed bursts** -
   when more writes are attempted than the FIFO can accept, predicting
   acceptance inside the same stimulus loop that asserts `w_incr` reads a
   stale (pre-effect) `w_incr`/`w_full`, off by one cycle. A separate
   `always @(posedge w_clk)` monitor block, evaluated at the correct edge,
   fixes the accept/reject *count*; for exact-value prediction in this
   scenario, checking gap-free consecutive values on drain (rather than
   predicting the absolute value per write) sidesteps a cross-process
   value-capture race entirely.

## Running the tests (Vivado)

1. Add the DUT source files (`asyncfifo.v` and submodules, or split per-file)
   as Design Sources.
2. Add the desired testbench file as a Simulation Source.
3. Set it as the simulation Top (right-click → Set as Top) if not automatic.
4. Run Behavioral Simulation, then `run -all` in the Tcl console to run to
   completion (the default simulation window is only 1000ns).

## Running the tests (Icarus Verilog / open-source flow)

```bash
iverilog -o sim.vvp tb_asyncfifo_all_cases.v asyncfifo.v
vvp sim.vvp
gtkwave tb_asyncfifo_all_cases.vcd
```

## Reference

Cummings, C. E. *"Simulation and Synthesis Techniques for Asynchronous FIFO
Design."* SNUG 2002, Sunburst Design, Inc.

