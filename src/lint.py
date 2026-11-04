#!/usr/bin/env python3
# Formatting and compiler warnings, as one check (Dominic: "we should be using the formatter and checking for compiler
# warnings"). Run from src: python3 lint.py [--fix]
#   - lobsterfmt (~/Dev/lobster/bin/lobsterfmt) must leave every .lobster file under src/ as it is; --fix writes it.
#   - every program in src/ compiles with no warnings. A global "use let" warning only counts when nothing under src/
#     reassigns that name: a shared global set only by another program (gen/reset for the game, voxel_proto for the
#     sheet's options) looks unassigned in the programs that don't include that code.
# Exit 1 on anything found.
import os
import re
import subprocess
import sys

LOBSTER = os.environ.get("LOBSTER", os.path.expanduser("~/Dev/lobster/bin/lobster"))
FMT = os.environ.get("LOBSTERFMT", os.path.expanduser("~/Dev/lobster/bin/lobsterfmt"))
src = os.path.dirname(os.path.abspath(__file__))
os.chdir(src)
fix = "--fix" in sys.argv[1:]
bad = []

fmt = subprocess.run([FMT, "-w" if fix else "-l", src], capture_output=True, text=True)
for line in fmt.stdout.splitlines():
    if line.strip() and not fix:
        bad.append("not formatted: " + os.path.relpath(line.strip(), src) + " (python3 lint.py --fix)")
if fmt.returncode not in (0,):
    bad.append("lobsterfmt failed:\n" + fmt.stdout + fmt.stderr)

sources = ""
for root, _, files in os.walk(src):
    for f in files:
        if f.endswith(".lobster"):
            sources += open(os.path.join(root, f), encoding="utf-8").read() + "\n"


def reassigned(name):
    return re.search(r"(^|[^.\w])" + re.escape(name) + r"\s*(=[^=]|\+=|-=|\*=|/=|\+\+|--)", sources, re.M) is not None


seen = set()
for prog in sorted(f for f in os.listdir(src) if f.endswith(".lobster")):
    out = subprocess.run([LOBSTER, "--compile-only", prog], capture_output=True, text=True)
    text = out.stdout + out.stderr
    if out.returncode != 0:
        bad.append(f"{prog}: doesn't compile:\n" + "\n".join(l for l in text.splitlines() if "warning" not in l)[:2000])
    for line in text.splitlines():
        if "warning:" not in line or line in seen:
            continue
        seen.add(line)
        m = re.search(r"use `let` to declare `(\w+)`", line)
        if m and reassigned(m.group(1)):
            continue
        bad.append(f"{prog}: {line}")

for b in bad:
    print(b)
print(f"lint: {len(bad)} problem{'' if len(bad) == 1 else 's'}")
sys.exit(1 if bad else 0)
