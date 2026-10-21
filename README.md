# DRAM→SRAM Saturating Vector Adder (SystemVerilog)

Near-memory unit that fetches two 8-byte signed vectors from a burst-mode SDRAM
(8-bit DQ, 8-beat bursts, 5-cycle latency), adds them element-wise with signed
saturation (−128…127), and writes the result to a 32-bit SRAM as two words.

## Design
- **Datapath**: registered DRAM/SRAM interfaces, 64-bit free-running shift register
  for vector A, a single 8-bit saturating adder used once per cycle as B streams in,
  32-bit result shift register, address register that holds `dst` then `dst+4`.
- **Control**: 5-state FSM (`IDLE → FETCH_A → ADD_HI → ADD_LO → DONE`) plus a
  5-bit cycle counter; READs spaced at the 8-cycle minimum for gap-free bursts.
- ~24 cycles per command, 212 flip-flops, no latches.

## Results
- Simulation (Questa): all provided tests pass, 100% SRAM match.
- Synthesis (Synopsys DC, Nangate 45 nm, 10 ns clock): setup slack +2.19 ns,
  hold slack +0.03 ns, 609 cells / 1643 µm².

## Files
- `srcs/rtl/dut.sv` — `dut_datapath`, `dut_control`, top-level `dut`

Built for NC State ECE 564 (ASIC design).
