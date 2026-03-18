# MIPS-Processor
## MIPS 5-Stage Pipeline CPU (Verilog)

This project implements a 32-bit MIPS processor using a 5-stage pipeline architecture in Verilog.

The pipeline consists of Instruction Fetch (IF), Instruction Decode (ID), Execute (EX), Memory (MEM), and Write Back (WB) stages. Pipeline registers are used between each stage to enable parallel instruction execution.

The CPU supports basic MIPS instructions including R-type operations, lw, sw, beq, bne, addi, and jump.

Hazard handling is implemented using:
- Forwarding (bypassing) to resolve data hazards
- Stall detection for load-use hazards
- Pipeline flushing for branch and jump instructions

The design includes separate instruction and data memory modules, a register file, and an ALU with multiple operations.

This implementation demonstrates core concepts of pipelined processor design, including performance optimization and hazard management.
