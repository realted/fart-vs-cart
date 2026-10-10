import argparse
import re
from collections import Counter
from pathlib import Path

ISA = (
    "LOAD STORE ADD SUB NAND ORI SHIFT LI BZ BNZ BPZ "
    "STOP NOP "
    "VLOAD VSTORE VADD VSUB VMUL VCMPLT VCMPGT VCMPEQ VCMCLR"
).split()

# Clock states per instruction in FSM.sv, including c1/c2 and vector
# decode states. STOP includes its first halt state, not indefinite halt time.
CYCLES_PER_INSTRUCTION = dict(zip(ISA, (
    4, 3, 4, 4, 4, 5, 4, 3, 3, 3, 3,
    4, 4,
    3, 3, 3, 3, 3, 3, 3, 3, 3,
)))

parser = argparse.ArgumentParser(
    description="Show static ISA instruction and cycle distributions."
)
parser.add_argument("file", type=Path, help="Input .s assembly file")
args = parser.parse_args()

try:
    source = args.file.read_text(encoding="utf-8-sig")
except (OSError, UnicodeError) as error:
    parser.exit(1, f"Error: {error}\n")

# Preserve line numbers while removing block comments.
source = re.sub(
    r"/\*.*?\*/",
    lambda match: " " + "\n" * match.group().count("\n"),
    source,
    flags=re.S,
)

counts = Counter({instruction: 0 for instruction in ISA})
unknown = []

for line_number, line in enumerate(source.splitlines(), 1):
    # Semicolon and // start comments. Keep # for immediate operands.
    line = re.split(r";|//", line, maxsplit=1)[0].strip()

    # Remove labels, including labels on instruction lines.
    while re.match(r"^(?:[A-Za-z_.$][\w.$]*|\d+)\s*:", line):
        line = re.sub(
            r"^(?:[A-Za-z_.$][\w.$]*|\d+)\s*:\s*", "", line, count=1
        ).strip()

    if not line or line.startswith("."):
        continue
    if re.match(r"^[A-Za-z_.$][\w.$]*\s*=", line):
        continue

    instruction = line.split()[0].upper()
    if instruction in counts:
        counts[instruction] += 1
    else:
        unknown.append((line_number, line))

total = sum(counts.values())
total_cycles = sum(counts[instruction] * CYCLES_PER_INSTRUCTION[instruction]
                   for instruction in ISA)

print(f"\nFile: {args.file}")
print(f"Total recognized instructions: {total}")
print(f"Total estimated cycles (static): {total_cycles}")
print("Each instruction is counted once; loops/branches are not simulated.")
print("Reset cycles and repeated STOP halt cycles are excluded.")
print(f"\n{'Instruction':<14} {'Count':>8} {'Percent':>10} "
      f"{'Cycles/instr':>12} {'Cycles':>10} {'Cycle %':>10}")
print("-" * 79)

for instruction in ISA:
    count = counts[instruction]
    percent = 100 * count / total if total else 0
    cycles_per_instruction = CYCLES_PER_INSTRUCTION[instruction]
    cycles = count * cycles_per_instruction
    cycle_percent = 100 * cycles / total_cycles if total_cycles else 0
    print(f"{instruction:<14} {count:>8} {percent:>9.2f}% "
          f"{cycles_per_instruction:>12} {cycles:>10} {cycle_percent:>9.2f}%")

print("-" * 79)
print(f"{'TOTAL':<14} {total:>8} {(100 if total else 0):>9.2f}% "
      f"{'':>12} {total_cycles:>10} {(100 if total_cycles else 0):>9.2f}%")

if unknown:
    print("\nUnknown statements (excluded from percentages):")
    for line_number, line in unknown:
        print(f"  Line {line_number}: {line}")
