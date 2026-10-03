#!/usr/bin/env python3
"""Двигает курсор в точку X Y. Использование: move-to.py X Y [delay_ms]"""
import subprocess, sys, time

def main():
    x = int(sys.argv[1])
    y = int(sys.argv[2])
    delay = int(sys.argv[3]) if len(sys.argv) > 3 else 80

    subprocess.run(["xdotool", "mousemove", str(x), str(y)], check=True)
    time.sleep(delay / 1000)
    print(f"moved to {x} {y}")

if __name__ == "__main__":
    main()
