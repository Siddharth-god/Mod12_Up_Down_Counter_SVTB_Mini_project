# MOD-12 Up/Down Counter Verification (SystemVerilog)

This project implements a SystemVerilog verification environment for a MOD-12 up/down counter.
The design is verified using a class-based testbench, reference model, scoreboard, and SystemVerilog Assertions (SVA).

## Key concepts learned
- Synchronization between driving and sampling
- Interface-based communication between TB and DUT
- Generator-driver-monitor architecture
- Reference model and scoreboard comparison
- Expected vs DUT output verification
- Timing discipline in verification
- Debugging mismatches systematically
- Assertion-based verification using SystemVerilog Assertions (SVA)

## Files
- udm12.sv – RTL implementation of MOD-12 up/down counter
- udm12_svtb.sv – SystemVerilog testbench with generator, driver, monitors, reference model, and scoreboard
- udm12_assertions.sv – Assertion module bound to the DUT to verify counter behavior

## Tool used
- QuestaSim
- VS Code

## Verification features
The design is verified using:

- Transaction-based stimulus generation
- Driver and monitors connected through an interface
- Reference model to compute expected results
- Scoreboard for DUT vs expected comparison
- SystemVerilog Assertions bound to the DUT to check:
  - Reset behavior
  - Load operation
  - Increment wrap (11 -> 0)
  - Decrement wrap (0 -> 11)
  - Correct up/down counting behavior

## Status
Verification environment implemented successfully with functional checks and SystemVerilog assertions.
