#!/usr/bin/env python3
# click.py X Y [задержка_мс] [--repeat N] [--gap мс]
# --repeat N  : нажать кнопку 1 всего N раз (для двойного клика N=2)
# --gap мс    : интервал между повторными кликами (по умолчанию 150; < порога KDE ~400мс)
import sys, time, subprocess

args = sys.argv[1:]
x = int(args[0]); y = int(args[1])
pre_delay = 300; repeat = 1; gap = 150
i = 2
if len(args) > 2 and not args[2].startswith("--"):
    pre_delay = int(args[2]); i = 3
while i < len(args):
    if args[i] == "--repeat" and i + 1 < len(args):
        repeat = int(args[i+1]); i += 2
    elif args[i] == "--gap" and i + 1 < len(args):
        gap = int(args[i+1]); i += 2
    else:
        i += 1

subprocess.run(["xdotool", "mousemove", str(x), str(y)])
time.sleep(pre_delay / 1000)
if repeat > 1:
    subprocess.run(["xdotool", "click", "--repeat", str(repeat), "--delay", str(gap), "1"])
else:
    subprocess.run(["xdotool", "click", "1"])
print(f"click {x} {y} (pre{pre_delay}ms, x{repeat}, gap{gap}ms)")
