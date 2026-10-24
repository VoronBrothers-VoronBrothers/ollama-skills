#!/usr/bin/env python3
"""convert_v2.py — универсальный txt → jsonl (новый стандарт, 23.10.2026).

Формат входного файла — блоки, разделённые строкой === :

    вопрос: ваш вопрос
    рассуждение: цепочка размышлений (может быть многострочной)
    ответ: финальный ответ
    ===
    вопрос: второй вопрос
    ответ: прямой ответ без рассуждения
    ===

- Заголовки регистронезависимы: Вопрос:/вопрос: — одно и то же.
- «рассуждение» необязательно; секции могут занимать несколько строк
  (всё до следующего заголовка).
- На выходе — формат messages (OpenAI-совместимый): assistant получает поле
  reasoning_content, если рассуждение было. Именно это поле шаблон чата Qwen
  оборачивает в think-блок при обучении.

Статистика: скрипт считает долю примеров с рассуждениями и предупреждает,
если их <75% (правило из руководства Unsloth по Qwen3.8: иначе модель теряет
способность к рассуждению).

Использование: python convert_v2.py файл.txt  → создаст файл.jsonl рядом.
"""
import json
import os
import re
import sys

HEADER_RE = re.compile(r'^\s*(вопрос|рассуждение|ответ)\s*:\s*(.*)$', re.IGNORECASE)
SECTION_KEYS = {"вопрос": "question", "рассуждение": "reasoning", "ответ": "answer"}


def parse_block(block):
    """Разбирает один блок на секции (поддерживает многострочные значения)."""
    sections = {"question": [], "reasoning": [], "answer": []}
    current = None
    for line in block.split("\n"):
        m = HEADER_RE.match(line)
        if m:
            current = SECTION_KEYS[m.group(1).lower()]
            sections[current].append(m.group(2))
        elif current is not None:
            sections[current].append(line)
    return {k: "\n".join(v).strip() for k, v in sections.items()}


def txt_to_jsonl(txt_path, out_path):
    with open(txt_path, "r", encoding="utf-8-sig") as f:
        blocks = f.read().split("===")

    dataset, skipped, reasoning_count = [], 0, 0
    for block in blocks:
        block = block.strip()
        if not block:
            continue
        s = parse_block(block)
        q, a, r = s["question"], s["answer"], s["reasoning"]
        if not q or not a:
            skipped += 1
            continue
        assistant_msg = {"role": "assistant", "content": a}
        if r:
            # reasoning_content — поле нового стандарта (Qwen оборачивает в think-блок)
            assistant_msg = {"role": "assistant", "reasoning_content": r, "content": a}
            reasoning_count += 1
        dataset.append({"messages": [{"role": "user", "content": q}, assistant_msg]})

    with open(out_path, "w", encoding="utf-8") as f:
        for item in dataset:
            f.write(json.dumps(item, ensure_ascii=False) + "\n")

    total = len(dataset)
    pct = (reasoning_count / total * 100) if total else 0
    print(f"Обработано {total} пар (пропущено {skipped}).")
    print(f"С рассуждениями: {reasoning_count} ({pct:.0f}%).")
    if total and pct < 75:
        print("⚠️ Рекомендуется ≥75% примеров с рассуждениями, "
              "иначе модель может потерять reasoning.")
    print(f"Сохранено: {out_path}")


def main():
    if len(sys.argv) < 2:
        print("Использование: python convert_v2.py название.txt")
        sys.exit(1)
    txt_path = sys.argv[1]
    if not os.path.isfile(txt_path):
        print(f"Ошибка: файл не найден — {txt_path}")
        sys.exit(1)
    base = os.path.splitext(txt_path)[0]
    out_path = base + ".jsonl"
    txt_to_jsonl(txt_path, out_path)


if __name__ == "__main__":
    main()
