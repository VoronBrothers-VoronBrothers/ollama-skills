#!/usr/bin/env python3
"""Сверяет фактическую позицию курсора с целевой. Использование: verify.py X Y [tolerance]"""
import subprocess, sys

def main():
    tx = int(sys.argv[1])
    ty = int(sys.argv[2])
    tol = int(sys.argv[3]) if len(sys.argv) > 3 else 3

    out = subprocess.run(
        ["xdotool", "getmouselocation"],
        capture_output=True, text=True
    ).stdout
    coords = {}
    for part in out.split():
        if ":" in part:
            k, v = part.split(":", 1)
            coords[k] = int(v)

    dx = abs(coords["x"] - tx)
    dy = abs(coords["y"] - ty)
    ok = dx <= tol and dy <= tol

    status = "OK" if ok else "DRIFT"
    print(f"{status} at {coords['x']} {coords['y']} (target {tx} {ty}, drift dx={dx} dy={dy})")
    sys.exit(0 if ok else 1)

if __name__ == "__main__":
    main()
