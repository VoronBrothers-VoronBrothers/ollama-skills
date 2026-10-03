#!/usr/bin/env python3
"""Модуль: нарисовать сетку с осями на картинке.

Использование:
    python3 grid-scale.py /tmp/input.png [--full-grid] [TICK_STEP]
Вывод: путь к обработанной картинке (stdout)

Флаг --full-grid: рисует сетку поверх изображения (тонкие серые линии).
"""
import sys, os
from PIL import Image, ImageDraw, ImageFont


MARGIN = 60
DEFAULT_TICK = 200


def add_scale(img_path: str, tick_step: int = DEFAULT_TICK, full_grid: bool = False) -> str:
    img = Image.open(img_path)
    w, h = img.size

    canvas = Image.new("RGB", (w + MARGIN, h + MARGIN), (255, 255, 255))
    canvas.paste(img.convert("RGB"), (MARGIN, MARGIN))
    draw = ImageDraw.Draw(canvas)

    # Шрифт: жирный, читаемый
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 20)
    except OSError:
        font = ImageFont.load_default()

    # Подписи осей
    draw.text((MARGIN + w // 2 - 15, 2), "X →", fill=(180, 0, 0), font=font)
    draw.text((2, MARGIN + h // 2 - 10), "Y ↓", fill=(0, 0, 180), font=font)

    # Промежуточные штрихи (X) — тонкие короткие между основными
    half_step = tick_step // 2
    for x in range(half_step, w + 1, tick_step):
        px = MARGIN + x
        draw.line([(px, 0), (px, MARGIN - 20)], fill=(180, 0, 0), width=1)

    # Вертикальные линии (X) — основные с подписями
    for x in range(0, w + 1, tick_step):
        px = MARGIN + x
        draw.line([(px, 0), (px, MARGIN)], fill=(180, 0, 0), width=3)
        label = str(x)
        bbox = draw.textbbox((0, 0), label, font=font)
        tw = bbox[2] - bbox[0]
        draw.rectangle([px - tw // 2 - 3, MARGIN + 4, px + tw // 2 + 3, MARGIN + 4 + (bbox[3] - bbox[1]) + 4], fill=(255, 255, 255))
        draw.text((px - tw // 2, MARGIN + 6), label, fill=(0, 0, 0), font=font)

    # Промежуточные штрихи (Y) — тонкие короткие между основными
    for y in range(half_step, h + 1, tick_step):
        py = MARGIN + y
        draw.line([(20, py), (MARGIN, py)], fill=(0, 0, 180), width=1)

    # Горизонтальные линии (Y) — 0 сверху, основные с подписями
    for y in range(0, h + 1, tick_step):
        py = MARGIN + y
        draw.line([(0, py), (MARGIN, py)], fill=(0, 0, 180), width=3)
        label = str(y)
        bbox = draw.textbbox((0, 0), label, font=font)
        tw = bbox[2] - bbox[0]
        lx = MARGIN - tw - 6
        ly = py - (bbox[3] - bbox[1]) // 2
        draw.rectangle([int(lx) - 2, int(ly) - 2, MARGIN, int(ly) + (bbox[3] - bbox[1]) + 2], fill=(255, 255, 255))
        draw.text((int(lx), int(ly)), label, fill=(0, 0, 0), font=font)

    # Полная сетка поверх изображения (только при --full-grid)
    if full_grid:
        grid_tick = 50  # точный шаг для полной сетки
        overlay_color_major = (180, 180, 180)   # основной — чуть темнее
        overlay_color_minor = (220, 220, 220)   # промежуточный — светлее
        for x in range(0, w + 1, grid_tick):
            px = MARGIN + x
            draw.line([(px, MARGIN), (px, MARGIN + h)], fill=overlay_color_major, width=1)
        half_step = grid_tick // 2
        for x in range(half_step, w + 1, grid_tick):
            px = MARGIN + x
            draw.line([(px, MARGIN), (px, MARGIN + h)], fill=overlay_color_minor, width=1)
        for y in range(0, h + 1, grid_tick):
            py = MARGIN + y
            draw.line([(MARGIN, py), (MARGIN + w, py)], fill=overlay_color_major, width=1)
        for y in range(half_step, h + 1, grid_tick):
            py = MARGIN + y
            draw.line([(MARGIN, py), (MARGIN + w, py)], fill=overlay_color_minor, width=1)

    out_path = img_path.replace(".png", "_scale.png")
    if out_path == img_path:
        out_path = img_path + "_scale.png"
    canvas.save(out_path)
    return out_path


if __name__ == "__main__":
    args = [a for a in sys.argv[1:]]
    full_grid = "--full-grid" in args
    if full_grid:
        args.remove("--full-grid")
    if len(args) < 1:
        print("использование: grid-scale.py /path/to/image.png [--full-grid] [tick_step]", file=sys.stderr)
        sys.exit(1)
    path = args[0]
    tick = int(args[1]) if len(args) > 1 else DEFAULT_TICK
    result = add_scale(path, tick, full_grid=full_grid)
    print(result)
