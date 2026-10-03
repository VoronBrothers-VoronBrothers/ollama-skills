#!/usr/bin/env python3
"""Модуль: плашка координат мыши.

Запуск (фоновый):
    python3 cursor-overlay.py start

Остановка:
    python3 cursor-overlay.py stop
"""
import subprocess, sys, os


def start():
    pid_file = "/tmp/cursor_overlay.pid"
    # уже запущен?
    if os.path.exists(pid_file):
        try:
            old_pid = int(open(pid_file).read().strip())
            os.kill(old_pid, 0)
            print(f"уже запущен (PID {old_pid})")
            return
        except (ValueError, ProcessLookupError, PermissionError):
            pass

    script = os.path.join(os.path.dirname(__file__), "cursor-overlay-worker.py")
    proc = subprocess.Popen(
        [sys.executable, script],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        env={**os.environ, "DISPLAY": ":0"},
    )
    with open(pid_file, "w") as f:
        f.write(str(proc.pid))
    print(f"запущен (PID {proc.pid})")


def stop():
    pid_file = "/tmp/cursor_overlay.pid"
    if os.path.exists(pid_file):
        try:
            pid = int(open(pid_file).read().strip())
            os.kill(pid, 15)
            print(f"остановлен (PID {pid})")
        except (ValueError, ProcessLookupError, PermissionError):
            print("не запущен")
    else:
        # fallback: pkill по имени воркера
        subprocess.run(["pkill", "-f", "cursor-overlay-worker.py"], capture_output=True)
        print("остановлен (pkill)")

    os.path.exists(pid_file) and os.remove(pid_file)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "stop"
    {"start": start, "stop": stop}.get(cmd, stop)()
