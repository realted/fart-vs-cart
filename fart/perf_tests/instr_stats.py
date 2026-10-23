"""Instruction/cycle statistics for the current 16-bit FART ISA.

Default: assemble into temporary files and execute from reset through STOP.
Use --static for source counts only. This is an ISA model, not RTL simulation.
"""
import argparse
import re
import subprocess
import tempfile
from collections import Counter
from pathlib import Path

ISA = ("LOAD STORE ADD SUB NAND ORI SHIFT LI BZ BNZ BPZ STOP NOP "
       "VLOAD VSTORE VADD VSUB VMUL VCMPLT VCMPGT VCMPEQ VCMCLR").split()
# FSM.sv: includes fetch/decode and first STOP state; excludes reset/idle halt.
CYCLES_PER_INSTRUCTION = dict(zip(ISA, (
    4, 3, 4, 4, 4, 5, 4, 3, 3, 3, 3, 4, 4,
    3, 3, 3, 3, 3, 3, 3, 3, 3,
)))


# KEND emits a completion pulse and clears the vector mask; it does not halt.
ISA.append('KEND')
CYCLES_PER_INSTRUCTION['KEND'] = 3


def static_counts(source):
    source = re.sub(r'/\*.*?\*/', '', source, flags=re.S)
    counts = Counter()
    for number, line in enumerate(source.splitlines(), 1):
        line = re.split(r';|//', line, maxsplit=1)[0].strip()
        if not line:
            continue
        fields = line.split(None, 1)
        op = fields[0].rstrip(':').upper()
        if op not in ISA + ['SHIFTL', 'SHIFTR', 'ORG', 'DB']:
            if len(fields) == 1:  # label on its own
                continue
            fields = fields[1].split(None, 1)
            op = fields[0].upper()
        if op in ('ORG', 'DB'):
            continue
        if op in ('SHIFTL', 'SHIFTR'):
            op = 'SHIFT'
        if op not in ISA:
            raise ValueError(f'Unknown statement near line {number}: {line}')
        counts[op] += 1
    return counts


def assemble(path, assembler):
    with tempfile.TemporaryDirectory(prefix='instr_stats_') as tmp:
        output = Path(tmp) / 'image.mif'
        result = subprocess.run([str(assembler.resolve()), str(path.resolve()),
                                 str(output)], capture_output=True, text=True)
        if result.returncode or not output.exists():
            raise ValueError('Assembly failed: ' + (result.stderr or result.stdout).strip())
        words = {int(a, 16): int(v, 16) for a, v in re.findall(
            r'^([0-9a-fA-F]+)\s*:\s*([0-9a-fA-F]+)', output.read_text(), re.M)}
        if set(words) != set(range(256)):
            raise ValueError('Expected a 256-word assembler image')
        return [words[i] for i in range(256)]


def signed(value):
    return value if value < 0x8000 else value - 0x10000


def execute(image, max_steps=1000000):
    # Separate program/data memories, both initialized from the assembler image.
    memory = image[:]
    regs = [0] * 4
    vectors = [[0] * 4 for _ in range(8)]
    pc, mask, z, n = 0, 15, False, False
    counts, branches = Counter(), Counter()
    scalar = {0: 'LOAD', 2: 'STORE', 4: 'ADD', 6: 'SUB', 8: 'NAND'}
    vector = {33: 'VLOAD', 34: 'VSTORE', 36: 'VADD', 37: 'VSUB',
              38: 'VMUL', 40: 'VCMPLT', 41: 'VCMPGT', 42: 'VCMPEQ'}
    for _ in range(max_steps):
        address = pc
        word = image[pc]
        pc = (pc + 1) & 255
        a, b = word >> 14, (word >> 12) & 3
        if word in (1, 0x8001):
            op = 'STOP' if word == 1 else 'NOP'
        elif word == 0x0002:
            op, mask = 'KEND', 15
        elif word == 0xFEF0:
            op, mask = 'VCMCLR', 15
        elif word & 7 == 4:
            op = 'LI'
            regs[a] = (word >> 3) & 2047
        elif word & 7 == 7:
            op = 'ORI'
            regs[1] |= word >> 3
            z, n = regs[1] == 0, bool(regs[1] & 0x8000)
        elif word & 7 == 3:
            op = 'SHIFT'
            shift = (word >> 3) & 7
            regs[a] = ((regs[a] << (shift & 3)) if shift & 4
                       else (regs[a] >> (shift & 3))) & 65535
            z, n = regs[a] == 0, bool(regs[a] & 0x8000)
        elif word & 15 in (5, 9, 13):
            op = {5: 'BZ', 9: 'BNZ', 13: 'BPZ'}[word & 15]
            taken = {'BZ': z, 'BNZ': not z, 'BPZ': not n}[op]
            offset = word >> 4
            if offset & 2048:
                offset -= 4096
            target = (pc + offset) & 255
            branches[address, op, target, taken] += 1
            if taken:
                pc = target
        elif word & 15 == 0 and (word >> 4) & 63 in vector:
            op = vector[(word >> 4) & 63]
            a, b = word >> 13, (word >> 10) & 7
            if op in ('VLOAD', 'VSTORE'):
                if b > 3:
                    raise ValueError(f'Invalid scalar address register at PC {address}')
                base = regs[b] & 255
                for lane in range(4):
                    addr = (base + lane) & 255
                    if op == 'VSTORE':
                        memory[addr] = vectors[a][lane]
                    elif mask & (1 << lane):
                        vectors[a][lane] = memory[addr]
            elif op.startswith('VCMP'):
                mask = 0
                for lane, (x, y) in enumerate(zip(vectors[a], vectors[b])):
                    condition = {'VCMPLT': signed(x) < signed(y),
                                 'VCMPGT': signed(x) > signed(y), 'VCMPEQ': x == y}[op]
                    if condition:
                        mask |= 1 << lane
            else:
                for lane in range(4):
                    if mask & (1 << lane):
                        x, y = vectors[a][lane], vectors[b][lane]
                        value = {'VADD': x+y, 'VSUB': x-y,
                                 'VMUL': (signed(x)*signed(y)) >> 8}[op]
                        vectors[a][lane] = value & 65535
        elif word & 63 == 0 and (word >> 6) & 63 in scalar:
            op = scalar[(word >> 6) & 63]
            if op == 'LOAD':
                regs[a] = memory[regs[b] & 255]
            elif op == 'STORE':
                memory[regs[b] & 255] = regs[a]
            else:
                x, y = regs[a], regs[b]
                regs[a] = {'ADD': x+y, 'SUB': x-y, 'NAND': ~(x & y)}[op] & 65535
                z, n = regs[a] == 0, bool(regs[a] & 0x8000)
        else:
            raise ValueError(f'Unsupported instruction {word:04X} at PC {address}')
        counts[op] += 1
        if op == 'STOP':
            return counts, branches, memory
    raise ValueError(f'Execution did not STOP within {max_steps} instructions '
                     f'(next PC={pc}); possible infinite loop. Increase --max-steps if needed.')


def report(counts):
    total = sum(counts.values())
    cycles = sum(counts[op] * CYCLES_PER_INSTRUCTION[op] for op in ISA)
    print(f"\n{'Instruction':<14} {'Count':>8} {'Percent':>10} "
          f"{'Cycles/instr':>12} {'Cycles':>10} {'Cycle %':>10}")
    print('-' * 79)
    for op in ISA:
        count, cost = counts[op], CYCLES_PER_INSTRUCTION[op]
        print(f'{op:<14} {count:>8} {100*count/total if total else 0:>9.2f}% '
              f'{cost:>12} {count*cost:>10} {100*count*cost/cycles if cycles else 0:>9.2f}%')
    print('-' * 79)
    print(f"{'TOTAL':<14} {total:>8} {100 if total else 0:>9.2f}% "
          f"{'':>12} {cycles:>10} {100 if cycles else 0:>9.2f}%")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('file', type=Path, help='Input .s assembly file')
    parser.add_argument('--static', action='store_true', help='Count each source instruction once')
    parser.add_argument('--max-steps', type=int, default=1000000, help='Execution limit (default: 1000000)')
    parser.add_argument('--assembler', type=Path,
                        default=Path(__file__).resolve().parent.parent / 'assembler' / 'asm.exe',
                        help='Project assembler executable')
    args = parser.parse_args()
    try:
        if args.max_steps < 1:
            raise ValueError('--max-steps must be positive')
        static = static_counts(args.file.read_text(encoding='utf-8-sig'))
        counts, branches = static, Counter()
        if not args.static:
            counts, branches, _ = execute(assemble(args.file, args.assembler), args.max_steps)
    except (OSError, UnicodeError, ValueError) as error:
        parser.exit(1, f'Error: {error}\n')
    mode = 'static' if args.static else 'executed'
    print(f'\nFile: {args.file}')
    print(f'Total source instructions (static): {sum(static.values())}')
    print(f'Total instructions ({mode}): {sum(counts.values())}')
    print(f'Total estimated cycles ({mode}): '
          f'{sum(counts[op]*CYCLES_PER_INSTRUCTION[op] for op in ISA)}')
    print('Reset cycles and repeated STOP halt cycles are excluded.')
    if not args.static:
        print('ISA execution from reset; separate program/data images; not an RTL timing simulation.')
    report(counts)
    if not args.static:
        print('\nBranches (PC and target are decimal word addresses):')
        for pc, op, target in sorted({key[:3] for key in branches}):
            print(f'  PC {pc}: {op} -> {target}: '
                  f'taken={branches[pc, op, target, True]}, '
                  f'not taken={branches[pc, op, target, False]}')
        if not branches:
            print('  None executed.')


if __name__ == '__main__':
    main()
