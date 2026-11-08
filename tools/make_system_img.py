#!/usr/bin/env python3
# Converts system.new.dat.br + system.transfer.list into system.img (same as we did for vendor).
# Run it from the folder that has both files:  python make_system_img.py
import os, sys, brotli

NAME = "system"
BLOCK = 4096
br_file, tl_file, out_file = NAME + ".new.dat.br", NAME + ".transfer.list", NAME + ".img"

for f in (br_file, tl_file):
    if not os.path.exists(f):
        sys.exit("Missing " + f + " - run this from the folder that has it.")

def ranges(s):
    n = [int(x) for x in s.split(",")]
    return [(n[i], n[i + 1]) for i in range(1, len(n), 2)]

lines = open(tl_file).read().split("\n")
version = int(lines[0])
cmds = lines[2:] if version == 1 else lines[4:]

new_ranges, max_block = [], 0
for line in cmds:
    p = line.split(" ")
    if p[0] == "new":
        for r in ranges(p[1]):
            new_ranges.append(r)
            max_block = max(max_block, r[1])
    elif p[0] in ("erase", "zero"):
        for r in ranges(p[1]):
            max_block = max(max_block, r[1])

total = sum(e - s for s, e in new_ranges) * BLOCK
dec = brotli.Decompressor()
buf = bytearray()
src = open(br_file, "rb")

def take(n):
    global buf
    while len(buf) < n:
        chunk = src.read(1 << 20)
        if not chunk:
            break
        buf += dec.process(chunk)
    out, buf = bytes(buf[:n]), buf[n:]
    return out

done = 0
with open(out_file, "wb") as out:
    out.truncate(max_block * BLOCK)
    for s, e in new_ranges:
        for b in range(s, e, 256):
            n = min(256, e - b)
            data = take(n * BLOCK)
            out.seek(b * BLOCK)
            out.write(data)
            done += len(data)
            pct = done * 100 // total
            bar = "#" * (pct // 2) + "-" * (50 - pct // 2)
            print("\r[" + bar + "] " + str(pct) + "%", end="", flush=True)

print("\nDone: " + out_file + " (" + str(os.path.getsize(out_file) // (1024 * 1024)) + " MB)")
