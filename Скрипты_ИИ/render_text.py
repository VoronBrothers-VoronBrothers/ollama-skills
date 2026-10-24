#!/usr/bin/env python3
"""render_text.py — ChatML jsonl → колонка "text" (24.10.2026).

Вход : dataset.jsonl от convert_v2.py — {"messages": [...]}, где у assistant может быть
       поле reasoning_content (шаблон Qwen сам оборачивает его в think-блок).
Выход: <имя>_text.jsonl рядом — {"text": "..."}, отрендерено чат-шаблоном модели.
       Готово к load_dataset("json", ...) + SFTConfig(dataset_text_field="text").

Использование: venv/bin/python render_text.py dataset.jsonl [model_name] [reasoning_effort]
reasoning_effort: medium (дефолт) — без system-инструкции, xhigh/low — с текстом уровня.
"""
import json
import sys

from transformers import AutoTokenizer


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else "dataset.jsonl"
    model_name = (sys.argv[2] if len(sys.argv) > 2
                 else "unsloth/Qwen3.8-27B-unsloth-bnb-4bit")
    reasoning_effort = sys.argv[3] if len(sys.argv) > 3 else "medium"

    tok = AutoTokenizer.from_pretrained(model_name, trust_remote_code=True)

    out_path = src.rsplit(".", 1)[0] + "_text.jsonl"
    n = skipped = think = 0
    with open(src, encoding="utf-8") as f, open(out_path, "w", encoding="utf-8") as out:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                messages = json.loads(line)["messages"]
                text = tok.apply_chat_template(
                    messages, tokenize=False, reasoning_effort=reasoning_effort)
            except Exception as e:  # noqa: BLE001 — строка не должна ронять весь прогон
                skipped += 1
                print(f"⚠️ Пропущено ({e}): {line[:80]}")
                continue
            n += 1
            think += "think" in text
            out.write(json.dumps({"text": text}, ensure_ascii=False) + "\n")

    pct = (think / n * 100) if n else 0
    print(f"Рендер: {n} строк (пропущено {skipped}), с think-блоком: {think} ({pct:.0f}%).")
    print(f"Сохранено: {out_path}")


if __name__ == "__main__":
    main()
