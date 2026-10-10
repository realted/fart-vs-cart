"""Split a linear 16-bit HEX MIF into four 256-word bank images.

Run from any directory: python split_data_banks.py [input.mif]
Outputs data_bank0.mif ... data_bank3.mif beside the input file.
Unspecified words are zero-filled. Regenerate after changing data.mif.
"""
from pathlib import Path
import re
import sys


def split(source):
    text = source.read_text(encoding="utf-8-sig")
    text = re.sub(r"%.*?%", "", text, flags=re.S)
    text = re.sub(r"--[^\n]*", "", text)
    def header(name):
        match = re.search(rf"\b{name}\s*=\s*(\w+)\s*;", text, re.I)
        if not match:
            raise ValueError(f"Missing {name}")
        return match[1].upper()
    depth = int(header("DEPTH"))
    if header("WIDTH") != "16" or not 1 <= depth <= 1024:
        raise ValueError("Expected WIDTH=16 and DEPTH between 1 and 1024")
    if header("ADDRESS_RADIX") != "HEX" or header("DATA_RADIX") != "HEX":
        raise ValueError("This splitter requires HEX address and data radices")
    body = re.search(r"\bCONTENT\s+BEGIN\b(.*?)\bEND\s*;", text, re.I | re.S)
    if not body:
        raise ValueError("Missing CONTENT BEGIN ... END")
    words = [0] * 1024
    for entry in body[1].split(";"):
        if not entry.strip():
            continue
        match = re.fullmatch(r"\s*(?:([0-9a-f]+)|\[\s*([0-9a-f]+)\s*\.\.\s*([0-9a-f]+)\s*\])\s*:\s*([0-9a-f]+)\s*", entry, re.I)
        if not match:
            raise ValueError(f"Unsupported MIF entry: {entry.strip()}")
        first = int(match[1] or match[2], 16)
        last = int(match[1] or match[3], 16)
        value = int(match[4], 16)
        if not 0 <= first <= last < depth or value > 0xffff:
            raise ValueError(f"Out-of-range MIF entry: {entry.strip()}")
        words[first:last + 1] = [value] * (last - first + 1)
    banks = [words[lane::4] for lane in range(4)]
    assert [banks[a % 4][a // 4] for a in range(1024)] == words
    for lane, bank in enumerate(banks):
        output = source.parent / f"data_bank{lane}.mif"
        content = "DEPTH = 256;\nWIDTH = 16;\nADDRESS_RADIX = HEX;\nDATA_RADIX = HEX;\nCONTENT BEGIN\n"
        content += "".join(f"{row:02X} : {value:04X};\n" for row, value in enumerate(bank))
        output.write_text(content + "END;\n", encoding="ascii")
        print(f"Wrote {output.name}: linear addresses {lane}, {lane + 4}, ...")


if __name__ == "__main__":
    split(Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).with_name("data.mif"))
