"""Regression checks for the 16-bit ISA. Run: python test_assembler.py [asm.exe]"""
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent
EXE = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / 'asm.exe'

def words(path):
    return {int(a, 16): int(v, 16) for a, v in re.findall(
        r'^([0-9a-fA-F]+)\s*:\s*([0-9a-fA-F]+)', path.read_text(), re.M)}

with tempfile.TemporaryDirectory(prefix='isa16_') as tmp:
    folder = Path(tmp)
    source, output = folder / 'input.s', folder / 'data.mif'

    def assemble(text):
        source.write_text(text)
        result = subprocess.run([str(EXE), str(source), str(output)], capture_output=True, text=True)
        assert result.returncode == 0, result.stderr
        mif = output.read_text()
        assert 'WIDTH = 16;' in mif and 'DEPTH = 256;' in mif
        assert len(re.findall(r'^\w+ : [0-9A-F]{4};$', mif, re.M)) == 256
        data = words(output)
        assert len(data) == 256 and data == words(Path(str(output) + '.mem'))
        return data

    # Golden words independently transcribed from the new ISA layout.
    golden = [
        ('load k1,(k2)', 0x6000), ('store k1,(k2)', 0x6080),
        ('add k1,k2', 0x6100), ('sub k1,k2', 0x6180),
        ('nand k1,k2', 0x6200), ('vload v1,(k2)', 0x2A10),
        ('vstore v1,(k2)', 0x2A20), ('vadd v1,v2', 0x2A40),
        ('vadd x1,x2', 0x2A40), ('ori 8191', 0xFFFF), ('ori 0', 0x0007),
        ('shiftl k1,2', 0x4033), ('shiftr k3,3', 0xC01B),
        ('shift k2,7', 0x803B), ('bz -2048', 0x8005),
        ('bnz 2047', 0x7FF9), ('bpz -1', 0xFFFD),
        ('vsub v1,v2', 0x2A50), ('vmul v1,v2', 0x2A60),
        ('vcmplt v1,v2', 0x2A80), ('vcmpgt v1,v2', 0x2A90),
        ('vcmpeq v1,v2', 0x2AA0), ('vcmclr', 0xFEF0),
        ('vcmclr ; enable all lanes', 0xFEF0), ('nop', 0x8001), ('stop', 0x0001),
        ('db 256', 0x0100), ('db 65535', 0xFFFF), ('db -32768', 0x8000),
        ('db -1', 0xFFFF), ('db $ABCD', 0xABCD), ('db %100000000', 0x0100),
    ]
    data = assemble(''.join('    ' + op + '\n' for op, _ in golden))
    assert [data[i] for i in range(len(golden))] == [value for _, value in golden]

    aliases = assemble('    vsub x1,x2\n    vmul x1,x2\n    vcmplt x1,x2\n    vcmpgt x1,x2\n    vcmpeq x1,x2\n')
    assert [aliases[i] for i in range(5)] == [0x2A50,0x2A60,0x2A80,0x2A90,0x2AA0]

    # All register combinations and both shift directions.
    for op, opcode in [('load', 0), ('store', 2), ('add', 4), ('sub', 6),
                       ('nand', 8), ('vload', 33), ('vstore', 34), ('vadd', 36), ('vsub', 37), ('vmul', 38),
                       ('vcmplt', 40), ('vcmpgt', 41), ('vcmpeq', 42)]:
        cases = []
        for a in range(8 if op.startswith("v") else 4):
            for b in range(8 if op.startswith("v") and op not in ("vload", "vstore") else 4):
                first = ('v' if op.startswith('v') else 'k') + str(a)
                second = ('v' if op in ('vadd','vsub','vmul','vcmplt','vcmpgt','vcmpeq') else 'k') + str(b)
                if op.endswith(('load', 'store')):
                    second = '(' + second + ')'
                cases.append((f'    {op} {first},{second}\n', ((a << 13) | (b << 10) | (opcode << 4)) if op.startswith("v") else ((a << 14) | (b << 12) | (opcode << 6))))
        data = assemble(''.join(t for t, _ in cases))
        assert [data[i] for i in range(len(cases))] == [v for _, v in cases]
    for reg in range(4):
        for count in range(4):
            data = assemble(f'    shiftl k{reg},{count}\n    shiftr k{reg},{count}\n')
            assert data[0] == (reg << 14) | ((count | 4) << 3) | 3
            assert data[1] == (reg << 14) | (count << 3) | 3

    data = assemble('start   nop\n    bz end\n    bnz start\nend     stop\n')
    assert [data[i] for i in range(4)] == [0x8001, 0x0015, 0xFFD9, 1]
    data = assemble('    org 255\n    db 300\n')
    assert data[255] == 300

    for text in ['vcmclr v0', 'vload v7,(k4)', 'vstore v8,(k0)', 'vadd x8,x0', 'vmul k0,v1', 'vsub v0,k1', 'vcmplt v0,v8',
                 'vcmpgt v0', 'vcmpeq k0,k1', 'ori -1', 'ori 8192', 'shiftl k0,4', 'shiftr k0,-1', 'shift k0,8',
                 'bz -2049', 'bnz 2048', 'db -32769', 'db 65536', 'db 4294967296',
                 'load v0,(k1)', 'vload k0,(k1)', 'vload v0,(v1)', 'vadd v0,k1',
                 'add k4,k1', 'add k1', 'org 256', 'org -1', 'bz missing',
                 'org 255\n    nop\n    stop', 'db 1\n    org 0\n    db 2']:
        source.write_text('    ' + text + '\n')
        output.write_text('KEEP MIF')
        Path(str(output) + '.mem').write_text('KEEP MEM')
        result = subprocess.run([str(EXE), str(source), str(output)], capture_output=True, text=True)
        assert result.returncode != 0, text
        assert output.read_text() == 'KEEP MIF', text
        assert Path(str(output) + '.mem').read_text() == 'KEEP MEM', text

    data = assemble((ROOT / 'test1_16bit_path.s').read_text())
    expected_ops = [0x0087, 0x4033, 0x0610, 0x0027, 0x2610,
                    0x0640, 0x5180, 0x0097, 0x4033, 0x0620]
    assert [data[i * 4] for i in range(10)] == expected_ops
    assert all(data[i * 4 + j] == 0x8001 for i in range(10) for j in (1, 2, 3))
    assert data[40] == 1
    assert [data[i] for i in range(64, 72)] == [255, 255, 128, 200, 1, 2, 128, 100]

    # ISA-level execution, not an RTL simulation. Decode words, not source text.
    mem = [data[i] for i in range(256)] + [0] * (65536 - 256)
    scalar, vector, pc = [0] * 4, [[0] * 4 for _ in range(8)], 0
    for steps in range(1000):
        ins = mem[pc]
        pc = (pc + 1) & 65535
        if ins == 1:
            break
        if ins == 0x8001:
            continue
        if ins & 7 == 7:
            scalar[1] |= ins >> 3
        elif ins & 7 == 3:
            reg, imm = ins >> 14, (ins >> 3) & 2047
            assert imm < 8
            scalar[reg] = ((scalar[reg] << (imm & 3)) if imm & 4 else
                           (scalar[reg] >> (imm & 3))) & 65535
        elif ins & 15 == 0 and ((ins >> 4) & 63) in (33,34,36):
            a,b,opcode = ins >> 13, (ins >> 10) & 7, (ins >> 4) & 63
            if opcode == 33:
                vector[a] = [mem[(scalar[b]+lane)&65535] for lane in range(4)]
            elif opcode == 36:
                vector[a] = [(x+y)&65535 for x,y in zip(vector[a],vector[b])]
            else:
                for lane in range(4): mem[(scalar[b]+lane)&65535] = vector[a][lane]
        elif ins & 63 == 0 and ((ins >> 6) & 63) == 6:
            a,b = ins >> 14, (ins >> 12)&3
            scalar[a] = (scalar[a]-scalar[b])&65535
        else:
            raise AssertionError(f'Unexpected instruction {ins:04X}')
    else:
        raise AssertionError('Program did not stop')
    assert mem[72:76] == [0x0100, 0x0101, 0x0100, 0x012C], mem[72:76]
    print('PASS: encodings, register combinations, immediate bounds, labels, errors, both output formats.')
    print('PASS: test1_16bit_path.s halts; ISA model memory[72:76] = 0100 0101 0100 012C.')
