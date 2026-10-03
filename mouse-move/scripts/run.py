#!/usr/bin/env python3
"""Энтрипоинт mouse-move: запускает плагина из pipeline.json по порядку.
Использование: run.py X Y [delay_ms] [--tolerance N]"""
import json, os, subprocess, sys

def main():
    if len(sys.argv) < 3:
        print("Usage: run.py X Y [delay_ms] [--tolerance N]")
        sys.exit(1)

    x = sys.argv[1]
    y = sys.argv[2]
    delay = sys.argv[3] if len(sys.argv) > 3 and not sys.argv[3].startswith("--") else "80"
    tolerance = "3"
    for i, a in enumerate(sys.argv):
        if a == "--tolerance" and i + 1 < len(sys.argv):
            tolerance = sys.argv[i+1]

    # Путь к pipeline.json — рядом с этим скриптом
    base = os.path.dirname(os.path.abspath(__file__))
    with open(os.path.join(base, "pipeline.json")) as f:
        steps = json.load(f)

    results = []
    for step in steps:
        if not step.get("enabled", True):
            continue
        name = step["name"]
        script = os.path.join(base, "plugins", f"{name}.py")

        # Собираем аргументы для плагина
        args = ["python3", script]
        if name == "move-to":
            args += [x, y, delay]
        elif name in ("get-cursor",):
            pass  # без аргументов
        elif name == "verify":
            args += [x, y, tolerance]
        else:
            args += [x, y]

        r = subprocess.run(args, capture_output=True, text=True)
        line = (r.stdout or "").strip()
        if not line and r.returncode != 0:
            line = f"ERROR rc={r.returncode}: {(r.stderr or '').strip()}"
        results.append(f"[{name}] {line}")

    # Финальный отчёт
    print("\n".join(results))

if __name__ == "__main__":
    main()
