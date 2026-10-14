# 4-bit CPU Datapath with a 3-Stage Pipeline

Verilog implementation of a compact 4-bit RISC-style CPU developed in AMD Vivado 2026.1.
The project extends a reusable 4-bit ALU into a Harvard CPU with an IF/ID/EX pipeline.

## Author

- Student: Vuong Tri Tien
- Roll number: HE190717

## Target

- FPGA: AMD Artix-7 `xc7a35tftg256-2L`
- Datapath width: 4 bits
- Address width: 4 bits
- Instruction width: 12 bits
- Instruction memory: 16 x 12 bits
- Data memory: 16 x 4 bits
- Register file: four 4-bit registers, R0-R3

## Pipeline

The processor uses three stages:

1. IF - fetch the instruction addressed by the program counter.
2. ID - decode the instruction and store its control/data fields in the ID/EX register.
3. EX - read operands, execute the ALU or memory operation, write back results, and resolve branches.

Taken `JMP` and `JZ` instructions are resolved in EX and flush the two younger pipeline entries.
Register operands are read in EX, so the directed tests handle back-to-back dependencies without forwarding or stalls.

## Instruction Set

| Opcode | Instruction | Operation |
| --- | --- | --- |
| `0` | `ADD Rd, Rs` | `Rd <- Rd + Rs` |
| `1` | `SUB Rd, Rs` | `Rd <- Rd - Rs` |
| `2` | `AND Rd, Rs` | `Rd <- Rd & Rs` |
| `3` | `OR Rd, Rs` | `Rd <- Rd \| Rs` |
| `4` | `XOR Rd, Rs` | `Rd <- Rd ^ Rs` |
| `5` | `NOT Rd` | `Rd <- ~Rd` |
| `6` | `LDI Rd, imm` | Load a 4-bit immediate |
| `7` | `MOV Rd, Rs` | Copy `Rs` to `Rd` |
| `8` | `LOAD Rd, addr` | Read data memory |
| `9` | `STORE Rd, addr` | Write data memory |
| `A` | `JMP addr` | Unconditional jump |
| `B` | `JZ addr` | Jump when the stored Zero flag is set |
| `C-F` | Reserved | NOP |

Instruction format: `[11:8] opcode`, `[7:6] Rd`, `[5:4] Rs`, `[3:0] immediate/address`.

## Verification

The self-checking CPU testbench passes all 42 checks. It covers pipeline fill and overlap,
arithmetic and logic operations, register write-back, memory access, flags, taken and non-taken
branches, and pipeline flushing.

Expected final simulation message:

```text
PASS: ALL 42 PIPELINED CPU CHECKS PASSED
```

## Vivado Results

Synthesis completed successfully for the target device:

- Slice LUTs: 37
- Slice registers: 60
- Block RAM tiles: 0
- DSPs: 0
- Bonded IOBs: 52

Implementation timing and DRC results are not included because the project currently has no XDC clock constraint.

## Opening and Simulating

1. Open `cpu4bit_datapath.xpr` in AMD Vivado 2026.1.
2. Set `cpu_4bit_tb` as the simulation top if Vivado does not select it automatically.
3. Run **Behavioral Simulation** and then **Run All**.
4. Check the Tcl Console for the final PASS message.

The main testbench and memory program are stored under `cpu4bit_datapath.srcs/sim_1/`.
