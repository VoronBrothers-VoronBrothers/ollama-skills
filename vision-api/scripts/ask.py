#!/usr/bin/env python3
"""
ask.py — единая точка входа для зрения.

Режимы:
  Авто (что на экране сейчас):
    python3 ask.py "вопрос"
  Файл (существующее изображение):
    python3 ask.py /путь/к/файлу.png "вопрос"
"""

import subprocess, sys, os, time

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CURSOR_OVERLAY = os.path.join(SCRIPT_DIR, "cursor_overlay.py")
ASK_OLD = os.path.join(SCRIPT_DIR, "ask_old.py")
SCREENSHOT_PATH = "/tmp/vision_api_screen.png"


def detect_mode(args):
    """Если первый аргумент — существующий файл → режим 'file', иначе 'auto'."""
    if args and os.path.isfile(os.path.expanduser(args[0])):
        return "file", args
    # Нет файла в аргументах → auto
    question = " ".join(args) if args else "Что на экране? Изображение 1920 х 1080"
    return "auto", [question]


def run_auto(question):
    """Оверлей → скриншот → ask_old."""
    overlay_proc = subprocess.Popen(
        [sys.executable, CURSOR_OVERLAY],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )
    try:
        time.sleep(0.5)  # даём плашке отрисоваться

        # Скриншот с активной плашкой
        subprocess.run(
            ["gnome-screenshot", "-f", SCREENSHOT_PATH],
            env={**os.environ, "DISPLAY": ":0"},
            capture_output=True
        )

        if not os.path.isfile(SCREENSHOT_PATH):
            print("Ошибка: не удалось снять экран", file=sys.stderr)
            sys.exit(1)

        result = subprocess.run(
            [sys.executable, ASK_OLD, SCREENSHOT_PATH, question],
            capture_output=True, text=True
        )
    finally:
        overlay_proc.terminate()

    if result.stdout:
        print(result.stdout)
    if result.stderr:
        print(result.stderr, file=sys.stderr)
    sys.exit(result.returncode)


def run_file(image_path, question):
    """Просто показать файл модели."""
    result = subprocess.run(
        [sys.executable, ASK_OLD, os.path.expanduser(image_path), question],
        capture_output=True, text=True
    )
    if result.stdout:
        print(result.stdout)
    if result.stderr:
        print(result.stderr, file=sys.stderr)
    sys.exit(result.returncode)


def main():
    args = sys.argv[1:]
    mode, parsed_args = detect_mode(args)

    if mode == "auto":
        run_auto(parsed_args[0])
    else:
        # parsed_args = [file_path, ...rest] — вопрос может быть пустым
        question = " ".join(parsed_args[1:]) if len(parsed_args) > 1 else "Что изображено? Изображение 1920 х 1080"
        run_file(parsed_args[0], question)


if __name__ == "__main__":
    main()
