#!/usr/bin/env python3
"""click_xy.py — клик мышью по координатам X Y (Kubuntu/X11, pyautogui).
Использование: click_xy.py <X> <Y> [задержка_сек]
Пример: click_xy.py 1235 1050
Stop: увести мышь в левый верхний угол экрана (FAILSAFE)."""
import sys, time
import pyautogui
pyautogui.FAILSAFE = True

def main():
    if len(sys.argv) < 3:
        print("Использование: click_xy.py <X> <Y> [задержка_сек]")
        sys.exit(1)
    try:
        x, y = int(sys.argv[1]), int(sys.argv[2])
        delay = float(sys.argv[3]) if len(sys.argv) > 3 else 0.5
    except ValueError:
        print("Ошибка: координаты должны быть целыми числами")
        sys.exit(1)

    w, h = pyautogui.size()
    if not (0 <= x <= w and 0 <= y <= h):
        print(f"Ошибка: ({x},{y}) вне экрана {w}x{h}")
        sys.exit(1)

    print(f"Клик по ({x}, {y})")
    pyautogui.moveTo(x, y, duration=0.2)
    time.sleep(delay)
    pyautogui.click()
    print("Готово")

if __name__ == "__main__":
    main()
