#!/usr/bin/env python3
"""Проверяет что плашка курсора запущена. Если нет — запускает в фоне."""
import subprocess, sys, time

def main():
    # Ищем процесс worker'а
    r = subprocess.run(
        ["pgrep", "-f", "cursor-overlay-worker.py"],
        capture_output=True
    )
    if r.returncode == 0:
        print("overlay ok")
        return

    # Запускаем в фоне, не привязывая к терминалу
    worker = "/home/voron/.ollama/skills/selfshot-2/scripts/cursor-overlay-worker.py"
    subprocess.Popen(
        ["python3", worker],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True
    )
    time.sleep(0.5)  # ждём инициализацию Tkinter
    print("overlay started")

if __name__ == "__main__":
    main()
