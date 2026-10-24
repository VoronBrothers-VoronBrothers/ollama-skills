#!/usr/bin/env python3
"""
DPO конвертер: txt → jsonl

Формат входного файла (пары разделены ===):
    Вопрос: текст вопроса
    Ответ: хороший ответ (chosen)
    Говно: плохой ответ (rejected)
    ===
    Вопрос: ещё вопрос
    Ответ: ещё хороший
    Говно: ещё плохой

Запуск: python3 dpo_convert.py имяфайла.txt
Результат: имяфайла.jsonl рядом с исходником.
"""

import json
import os
import sys


def txt_to_dpo_jsonl(txt_path, out_path):
    with open(txt_path, 'r', encoding='utf-8') as f:
        blocks = f.read().split('===')

    dataset = []
    skipped = 0

    for i, block in enumerate(blocks):
        block = block.strip()
        if not block:
            continue

        question = ""
        chosen = ""
        rejected = ""

        for line in block.split('\n'):
            line = line.strip()
            if line.startswith("Вопрос:"):
                question = line[len("Вопрос:"):].strip()
            elif line.startswith("Ответ:"):
                chosen = line[len("Ответ:"):].strip()
            elif line.startswith("Говно:"):
                rejected = line[len("Говно:"):].strip()

        # Все три поля обязательны
        if question and chosen and rejected:
            dataset.append({
                "prompt": question,
                "chosen": chosen,
                "rejected": rejected
            })
        else:
            skipped += 1

    with open(out_path, 'w', encoding='utf-8') as f:
        for item in dataset:
            f.write(json.dumps(item, ensure_ascii=False) + '\n')

    print(f"Обработано пар: {len(dataset)}")
    if skipped:
        print(f"Пропущено блоков (неполные): {skipped}")
    print(f"Файл сохранён: {out_path}")


def main():
    if len(sys.argv) < 2:
        print("Использование: python3 dpo_convert.py имяфайла.txt")
        sys.exit(1)

    txt_path = sys.argv[1]

    if not os.path.isfile(txt_path):
        print(f"Ошибка: файл не найден — {txt_path}")
        sys.exit(1)

    base = os.path.splitext(txt_path)[0]
    out_path = base + '.jsonl'

    txt_to_dpo_jsonl(txt_path, out_path)


if __name__ == '__main__':
    main()
