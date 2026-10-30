#!/usr/bin/env python3
"""Rebuild PNGs from a CI log that contains 'B64 <name> <chunk>' lines.
   python tools/decode_ci_screens.py <log.txt> <out_dir>"""
import base64, os, re, sys
log, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
parts = {}
for line in open(log, encoding="utf-8", errors="replace"):
    m = re.search(r"B64 (\S+) ([A-Za-z0-9+/=]+)\s*$", line)
    if m:
        parts.setdefault(m.group(1), []).append(m.group(2))
for name, chunks in parts.items():
    with open(os.path.join(out, name + ".png"), "wb") as f:
        f.write(base64.b64decode("".join(chunks)))
    print("wrote", name)
