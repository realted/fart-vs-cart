# 16-bit processor assembler

Build with `g++ -std=c++11 -Wall -Wextra -pedantic asm.cpp -o asm.exe`.
A rebuilt Windows executable is included.

From this folder, run:

```powershell
.\asm.exe .\test1_16bit_path.s
```

This produces `data.mif` and `data.mif.mem` in the current directory. An optional
second argument selects the MIF path; `.mem` is appended for the simulation file.
Both formats contain 256 16-bit words, matching the current RAM depth. Copy both
to the Quartus project folder after assembling, or specify `..\data.mif` as output.
A wider instruction/data word does not itself increase RAM depth.

## Encoding and operands

The authoritative encoding table is in `../../documentation/ISA_documentation.txt`.
The SHIFT clarification below was confirmed by the processor author.

| Instruction | Encoding / range |
| --- | --- |
| LOAD, STORE, ADD, SUB, NAND | `(R1 << 14) \| (R2 << 12) \| (opcode << 6)`; opcodes 0, 2, 4, 6, 8 |
| VLOAD, VSTORE, VADD | Same layout; opcodes 32, 34, 36 |
| ORI | `(imm13 << 3) \| 7`; immediate 0..8191 |
| SHIFT | `(R1 << 14) \| (imm11 << 3) \| 3`; only low 3 immediate bits are used |
| BZ, BNZ, BPZ | `((offset & 0xFFF) << 4) \| tag`; tags 5, 9, 13; offset -2048..2047 |
| STOP / NOP | `0001` / `8001` |

Scalar registers: `k0` through `k3`. Vector registers: `v0` through `v3`, with
`x0` through `x3` accepted as aliases. Loads/stores use a scalar address register:
`load k0,(k1)`, `vload v0,(k1)`. Arithmetic uses `add k0,k1` or `vadd v0,v1`.
Register classes are checked; scalar/vector operands cannot be mixed.

`shiftl k1,2` sets immediate bit 2; `shiftr k1,2` clears it. Bits 1:0 contain
the count (0..3); immediate bits 10:3 are zero. `shift k1,N` accepts the raw
three-bit field, 0..7. Direction 1 means left, 0 means right.

Branches accept a signed numeric offset or a label, relative to the next
instruction (`target - current_address - 1`). Immediates are range-checked.

## Source syntax

Keep instructions/directives indented. Labels start in column one and have no
colon, e.g. `loop    add k0,k1`. Use lowercase mnemonics/registers, and no spaces
inside an operand pair (`k0,k1`). Semicolons start comments.

`org N` sets the word address (0..255). `db N` emits one **16-bit word** despite
its historical name: values -32768..65535 are accepted, with negative values
stored in two's complement. Decimal, `$` hexadecimal, `%` binary, leading-zero
octal, and single-character data literals are supported. Overlapping output
addresses and values outside the allowed ranges are errors. Assembly errors
are detected before existing output files are opened.

## Verification

```powershell
python .\test_assembler.py
```

Tests cover the encoding table, all register pairs, shift direction/counts,
branch labels and limits, invalid operands, 16-bit data, and agreement between
the MIF and ModelSim output. The unchanged `test1_16bit_path.s` also executes in
an ISA-level model and halts with memory words 72..75 equal to
`0100 0101 0100 012C`.

This is not a full RTL simulation. At the time of this update, `FSM.sv` receives
only `IR[11:6]`, so it cannot distinguish the low-bit ORI/SHIFT/branch tags or the
STOP/NOP marker defined by this ISA. The hardware decoder needs to inspect the
appropriate instruction bits before this program can run correctly on the FPGA.
