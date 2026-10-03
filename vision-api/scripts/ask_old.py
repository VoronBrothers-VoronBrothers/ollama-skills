#!/usr/bin/env python3
"""Одноразовый запрос к vision-модели с опциональной шкалой на изображении."""

import sys, json, base64, os, urllib.request
from io import BytesIO
from PIL import Image, ImageDraw, ImageFont

MARGIN = 60       # px отступ под подписи
TICK_STEP = 200   # шаг меток на шкале
GRID_COLOR = (180, 180, 180, 60)  # полупрозрачная сетка


def add_scale(img: Image.Image) -> tuple[Image.Image, int, int]:
    """Добавить оси с подписями. Y-ось как у курсора: 0 сверху."""
    w, h = img.size

    canvas = Image.new("RGB", (w + MARGIN, h + MARGIN), (255, 255, 255))
    canvas.paste(img.convert("RGB"), (MARGIN, MARGIN))

    draw = ImageDraw.Draw(canvas)

    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 20)
    except (OSError, IOError):
        font = ImageFont.load_default()

    # Подписи осей — большие и явные
    draw.text((MARGIN + w // 2 - 15, 2), "X →", fill=(180, 0, 0), font=font)
    draw.text((2, MARGIN + h // 2 - 10), "Y ↓", fill=(0, 0, 180), font=font)

    # X-ось (сверху): красные метки с белой подложкой под цифрой
    for x in range(0, w + 1, TICK_STEP):
        px = MARGIN + x
        draw.line([(px, 0), (px, MARGIN)], fill=(180, 0, 0), width=3)
        label = str(x)
        tw = draw.textlength(label, font=font)
        # Белая подложка чтобы линия не перечёркивала цифру
        bx1, by1 = int(px - tw / 2) - 2, 0
        bx2, by2 = int(px + tw / 2) + 2, 22
        draw.rectangle([bx1, by1, bx2, by2], fill=(255, 255, 255))
        draw.text((px - tw / 2, 2), label, fill=(180, 0, 0), font=font)

    # Y-ось (слева): синие метки с белой подложкой
    for y in range(0, h + 1, TICK_STEP):
        py = MARGIN + y
        draw.line([(0, py), (MARGIN, py)], fill=(0, 0, 180), width=3)
        label = str(y)
        tw = draw.textlength(label, font=font)
        lx = MARGIN - tw - 6
        # Белая подложка
        draw.rectangle([int(lx) - 2, int(py - 12), MARGIN, int(py + 10)], fill=(255, 255, 255))
        draw.text((lx, py - 10), label, fill=(0, 0, 180), font=font)

    # Сетка: X — красные толстые линии, Y — синие толстые линии
    for x in range(0, w + 1, TICK_STEP):
        px = MARGIN + x
        draw.line([(px, MARGIN), (px, MARGIN + h)], fill=(255, 80, 80), width=3)
    for y in range(0, h + 1, TICK_STEP):
        py = MARGIN + y
        draw.line([(MARGIN, py), (MARGIN + w, py)], fill=(80, 80, 255), width=3)

    # Рамка вокруг области изображения
    draw.rectangle([MARGIN, MARGIN, MARGIN + w, MARGIN + h], outline=(150, 150, 150), width=2)

    return canvas, w, h


def main():
    args = sys.argv[1:]

    # Вытаскиваем --scale если есть
    use_scale = "--scale" in args
    if use_scale:
        args.remove("--scale")

    if len(args) < 2:
        print("Использование: ask.py [--scale] ПУТЬ_К_КАРТИНКЕ ВОПРОС", file=sys.stderr)
        sys.exit(1)

    image_path = args[0]
    question = " ".join(args[1:])

    if not os.path.isfile(image_path):
        print(f"Ошибка: файл не найден: {image_path}", file=sys.stderr)
        sys.exit(1)

    img = Image.open(image_path)
    orig_w, orig_h = img.size

    if use_scale:
        img, orig_w, orig_h = add_scale(img)
        question += f" (изображение с шкалой, оригинальный размер {orig_w}x{orig_h}, Y-ось от низа)"
        # Сохраняем аннотированную копию для отладки
        debug_path = image_path.rsplit('.', 1)[0] + '_scale.png'
        img.save(debug_path)
        print(f"[debug] сохранено: {debug_path}", file=sys.stderr)

    # Кодируем в base64 из памяти (без временного файла)
    buf = BytesIO()
    img.save(buf, format="PNG")
    img_b64 = base64.b64encode(buf.getvalue()).decode()

    payload = {
        "model": "vision",
        "messages": [
            {"role": "system", "content": f"The image is {orig_w}x{orig_h} pixels (screen resolution 1920x1080). Describe in detail what you see."},
            {"role": "user", "content": question, "images": [img_b64]}
        ],
        "stream": False,
        "options": {"num_ctx": 8192}
    }

    data = json.dumps(payload).encode()
    req = urllib.request.Request(
        "http://localhost:11434/api/chat",
        data=data,
        headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        result = json.loads(resp.read())

    print(result["message"]["content"])


if __name__ == "__main__":
    main()
