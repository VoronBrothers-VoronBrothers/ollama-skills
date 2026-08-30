#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
X11-агент для orchestrator:latest (Ollama).
Глаза: PIL.ImageGrab (скриншот всего экрана) + координатная сетка.
Мозг : ollama chat (модель видит картинку, отдаёт одно JSON-действие).
Руки : pyautogui (клик/клавиши) + xdotool type (юникод).

Запуск:  python3 x11_agent.py "Открой меню приложений" [макс_шагов]
Стоп   : рывок мыши в левый верхний угол экрана (pyautogui.FAILSAFE) или Ctrl+C.
"""
import os
os.environ.setdefault("DISPLAY", ":0")

import sys
import json
import time
import shlex
import subprocess
from PIL import Image, ImageDraw, ImageFont, ImageGrab
import pyautogui
import ollama

# ---------- Константы ----------
SCREEN_W, SCREEN_H = 1920, 1080
GRID_STEP = 100          # шаг сетки в пикселях
MODEL = "orchestrator:latest"
SHOT_PATH = "/tmp/x11_agent_shot.png"

pyautogui.FAILSAFE = True   # рывок мыши в (0,0) = аварийный стоп
pyautogui.PAUSE = 0.4       # пауза между событиями мыши/клавиш


# ---------- Глаза ----------
def take_screenshot(path=SHOT_PATH):
    """Скриншот всего экрана + координатная сетка."""
    img = ImageGrab.grab()                      # весь основной экран
    if img.size != (SCREEN_W, SCREEN_H):
        img = img.resize((SCREEN_W, SCREEN_H))  # страховка от расхождений
    draw = ImageDraw.Draw(img)
    font = _font()

    # Вертикальные линии + подписи X (верх/низ)
    for x in range(0, SCREEN_W + 1, GRID_STEP):
        draw.line([(x, 0), (x, SCREEN_H)], fill=(255, 80, 80, 255), width=1)
        if font:
            draw.text((x + 3, 3), str(x), fill=(255, 255, 0))
            draw.text((x + 3, SCREEN_H - 18), str(x), fill=(255, 255, 0))

    # Горизонтальные линии + подписи Y (лево/право)
    for y in range(0, SCREEN_H + 1, GRID_STEP):
        draw.line([(0, y), (SCREEN_W, y)], fill=(255, 80, 80, 255), width=1)
        if font:
            draw.text((3, y + 3), str(y), fill=(255, 255, 0))
            draw.text((SCREEN_W - 45, y + 3), str(y), fill=(255, 255, 0))

    # Зелёные узлы на пересечениях (через одну) — локальные ориентиры
    for x in range(GRID_STEP, SCREEN_W, GRID_STEP * 2):
        for y in range(GRID_STEP, SCREEN_H, GRID_STEP * 2):
            if font:
                draw.text((x + 4, y + 4), f"{x},{y}", fill=(0, 255, 0))

    img.save(path)
    return path


def _font():
    try:
        return ImageFont.load_default(size=16)
    except Exception:
        try:
            return ImageFont.load_default()
        except Exception:
            return None


# ---------- Мозг ----------
SYSTEM_PROMPT = f"""Ты — ИИ-агент, управляющий Kubuntu (KDE/X11), экран {SCREEN_W}x{SCREEN_H}.
На скриншот наложена КРАСНАЯ сетка с шагом {GRID_STEP}px. Жёлтые цифры по краям и зелёные метки
на пересечениях — это точные координаты (X,Y). Используй их, чтобы вычислить центр цели.

Выдавай СТРОГО ОДИН JSON-объект без какого-либо лишнего текста:
{{"action":"click","x":<px>,"y":<px>}}                    — клик
{{"action":"double_click","x":<px>,"y":<px>}}             — двойной клик
{{"action":"type","text":"..."}}                          — ввести текст в активное поле
{{"action":"press","key":"enter|esc|backspace|tab|up|down"}} — одиночная клавиша
{{"action":"hotkey","keys":["ctrl","alt","t"]}}           — комбинация клавиш
{{"action":"scroll","amount":-500}}                       — прокрутка (минус = вниз)
{{"action":"wait","seconds":2}}                            — пауза
{{"action":"done","message":"..."}}                       — задача выполнена

Правила: одна команда за раз; координаты целые в пикселях; не выдумывай поле action."""


def ask_orchestrator(task, image_path, step, history):
    client = ollama.Client()
    user_msg = f"Задача: {task}\nШаг {step}. Какое одно следующее действие?"
    if history:
        user_msg += "\nПоследние действия: " + " | ".join(history[-3:])
    try:
        resp = client.chat(
            model=MODEL,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": user_msg, "images": [image_path]},
            ],
            options={"temperature": 0.1},
        )
        raw = (resp["message"]["content"] or "").strip()
    except Exception as e:
        print(f"[мозг] ошибка запроса: {e}")
        return {"action": "wait", "seconds": 2}

    action = _parse_json(raw)
    if not isinstance(action, dict) or "action" not in action:
        print(f"[мозг] не удалось разобрать: {raw[:120]!r}")
        return {"action": "wait", "seconds": 2}
    return action


def _parse_json(raw):
    """Достаёт JSON из ответа (обрезает ```json, текст вокруг)."""
    raw = raw.strip()
    a, b = raw.find("{"), raw.rfind("}")
    if a != -1 and b != -1 and b > a:
        try:
            return json.loads(raw[a:b + 1])
        except Exception:
            pass
    import re
    cleaned = re.sub(r"```(?:json)?\s*|```", "", raw).strip()
    try:
        return json.loads(cleaned)
    except Exception:
        return None


# ---------- Руки ----------
def execute_action(a):
    kind = a.get("action")

    if kind == "click":
        x, y = int(a["x"]), int(a["y"])
        print(f"[руки] click ({x},{y})")
        pyautogui.moveTo(x, y, duration=0.3)
        pyautogui.click()

    elif kind == "double_click":
        x, y = int(a["x"]), int(a["y"])
        print(f"[руки] double_click ({x},{y})")
        pyautogui.moveTo(x, y, duration=0.3)
        pyautogui.doubleClick()

    elif kind == "type":
        text = a.get("text", "")
        print(f"[руки] type: {text!r}")
        _type_text(text)

    elif kind == "press":
        key = str(a.get("key", "")).lower()
        print(f"[руки] press: {key}")
        pyautogui.press(key)

    elif kind == "hotkey":
        keys = a.get("keys", [])
        if isinstance(keys, str):
            keys = [k.strip() for k in keys.split("+")]
        print(f"[руки] hotkey: {'+'.join(keys)}")
        pyautogui.hotkey(*keys)

    elif kind == "scroll":
        amt = int(a.get("amount", -500))
        print(f"[руки] scroll {amt}")
        pyautogui.scroll(amt)

    elif kind == "wait":
        secs = float(a.get("seconds", 2))
        print(f"[руки] wait {secs}s")
        time.sleep(secs)

    elif kind == "done":
        print(f"[ruki] DONE: {a.get('message','')}")
        return True

    else:
        print(f"[руки] неизвестное действие: {kind!r}")
    return False


def _type_text(text):
    """Юникод/кириллица через xdotool; ASCII можно и pyautogui."""
    try:
        subprocess.run(["xdotool", "type", "--clearmodifiers", "--delay", "50", text],
                       check=True, timeout=30)
        return
    except Exception as e:
        print(f"[руки] xdotool не сработал ({e}), fallback pyautogui (ASCII only)")
    try:
        pyautogui.write(text, interval=0.05)
    except Exception:
        pass


# ---------- Цикл ----------
def run_agent(task, max_steps=25):
    print(f"🤖 Задача: {task}")
    print(f"🛑 Стоп: рывок мыши в левый верхний угол. Лимит шагов: {max_steps}")
    history = []
    for step in range(1, max_steps + 1):
        print(f"\n--- Шаг {step}/{max_steps} ---")
        img = take_screenshot()
        decision = ask_orchestrator(task, img, step, history)
        print(f"🤖 решение: {json.dumps(decision, ensure_ascii=False)}")
        if os.path.exists(img):
            os.remove(img)
        history.append(json.dumps(decision, ensure_ascii=False))
        done = execute_action(decision)
        if done:
            print("\n🎉 Агент завершил задачу.")
            return True
        time.sleep(0.8)
    print("\n⏹ Достигнут лимит шагов без done.")
    return False


def main():
    args = sys.argv[1:]
    task = " ".join(args).strip() or "Открой меню приложений K-Menu"
    max_steps = 25
    if task and task.lstrip("-").isdigit():
        try:
            max_steps = int(task)
        except Exception:
            pass
    run_agent(task, max_steps=max_steps)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n⏹ Остановлено пользователем.")
