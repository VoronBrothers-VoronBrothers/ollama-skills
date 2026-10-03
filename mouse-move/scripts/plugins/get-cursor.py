#!/usr/bin/env python3
"""Печатает текущие координаты курсора: x y"""
import subprocess, sys

def main():
    out = subprocess.run(
        ["xdotool", "getmouselocation"],
        capture_output=True, text=True
    ).stdout
    # Формат: x:123 y:456 screen 0 window ...
    coords = {}
    for part in out.split():
        if ":" in part:
            k, v = part.split(":", 1)
            coords[k] = int(v)
    print(f"{coords['x']} {coords['y']}")

if __name__ == "__main__":
    main()
