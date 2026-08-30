#!/usr/bin/env python3
# click.py X Y [задержка_мс перед кликом]
import sys, time, subprocess
x, y = int(sys.argv[1]), int(sys.argv[2])
delay = int(sys.argv[3]) if len(sys.argv) > 3 else 300
subprocess.run(["xdotool", "mousemove", str(x), str(y)])
time.sleep(delay / 1000)
subprocess.run(["xdotool", "click", "1"])
print(f"click {x} {y} (pause {delay}ms)")
