import tempfile
import unittest
from pathlib import Path
from instr_stats import assemble, execute, static_counts, CYCLES_PER_INSTRUCTION

ROOT = Path(__file__).resolve().parent.parent / 'assembler'


class StatsTests(unittest.TestCase):
    def run_source(self, text, limit=1000):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp)/'test.s'
            source.write_text(text)
            return execute(assemble(source, ROOT/'asm.exe'), limit)

    def test_existing_programs(self):
        for path in ROOT.glob('test*.s'):
            counts, branches, memory = execute(assemble(path, ROOT/'asm.exe'))
            self.assertEqual(counts['STOP'], 1)
            if path.name.startswith('test5'):
                self.assertEqual(sum(static_counts(path.read_text()).values()), 97)
                self.assertEqual(sum(counts.values()), 279)
                self.assertEqual(sum(v for k,v in branches.items() if k[3]), 2)
                self.assertEqual(sum(v for k,v in branches.items() if not k[3]), 1)
                self.assertEqual(memory[220:228], [256,64256,0,512,256,0,256,256])
            else:
                self.assertEqual(counts, static_counts(path.read_text()))
            if path.name.startswith('test1'):
                self.assertEqual(memory[72:76], [256,257,256,300])
            if path.name.startswith('test4'):
                self.assertEqual(sum(counts.values()), 87)
                self.assertEqual(sum(v*CYCLES_PER_INSTRUCTION[k] for k,v in counts.items()), 262)

    def test_flags_and_branch_paths(self):
        counts, branches, _ = self.run_source('''    li k0,2
    li k1,1
loop    sub k0,k1
    li k2,99
    bnz loop
    bz equal
    stop
equal    sub k0,k1
    bpz wrong
    add k0,k1
    bpz done
wrong    bnz wrong
done    stop
''')
        self.assertEqual(counts['BNZ'], 2)
        self.assertEqual(counts['BZ'], 1)
        self.assertEqual(counts['BPZ'], 2)
        self.assertEqual(sum(v for k,v in branches.items() if k[3]), 3)

    def test_loaded_counter_and_numeric_branch(self):
        counts, _, _ = self.run_source('''    li k1,100
    load k0,(k1)
    li k2,1
loop    sub k0,k2
    bnz -2
    stop
    org 100
count    db 3
''')
        self.assertEqual(counts['SUB'], 3)

    def test_infinite_loop(self):
        with self.assertRaisesRegex(ValueError, 'did not STOP'):
            self.run_source('loop    bnz loop\n', 20)


if __name__ == '__main__':
    unittest.main()
