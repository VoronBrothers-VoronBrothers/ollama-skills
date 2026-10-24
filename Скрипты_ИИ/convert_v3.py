#!/usr/bin/env python3
"""convert_v3.py — многоходовый txt → jsonl для Qwen3.8 (24.10.2026).

Формат:
  === разделяет ДИАЛОГИ
  --- разделяет РЕПЛИКИ внутри диалога

    вопрос: привет
    ответ: привет!
    ---
    вопрос: 2+2?
    рассуждение: 2 плюс 2 — это 4
    ответ: 4
    ===
    вопрос: ...

- reasoning_content — только у assistant (шаблон Qwen обернёт в <think>).
- system по умолчанию НЕ добавляется. Используйте --system "текст",
  если нужна персона/инструкция (см. предупреждения в статистике).

Использование:
  python convert_v3.py file.txt
  python convert_v3.py file.txt --system "Ты — юрист. Отвечай кратко."
  python convert_v3.py file.txt --strict     # падать на смешанных диалогах
"""
import argparse
import json
import os
import re
import sys

HEADER_RE = re.compile(r'^\s*(вопрос|рассуждение|ответ)\s*:\s*(.*)$', re.IGNORECASE)
SECTION_KEYS = {"вопрос": "question", "рассуждение": "reasoning", "ответ": "answer"}
BLOCK_SEP = re.compile(r'^\s*===\s*$', re.MULTILINE)
TURN_SEP = re.compile(r'^\s*---\s*$', re.MULTILINE)


def parse_turn(text):
    """Разбирает одну реплику на вопрос/рассуждение/ответ (многострочно)."""
    sections = {"question": [], "reasoning": [], "answer": []}
    current = None
    for line in text.split("\n"):
        m = HEADER_RE.match(line)
        if m:
            current = SECTION_KEYS[m.group(1).lower()]
            sections[current].append(m.group(2))
        elif current is not None:
            sections[current].append(line)
    return {k: "\n".join(v).strip() for k, v in sections.items()}


def parse_dialogue(block, system=None):
    """Возвращает (example, reasoning_turns, total_turns) или (None, 0, 0)."""
    messages = []
    if system:
        messages.append({"role": "system", "content": system})

    reasoning_turns = 0
    total_turns = 0
    for turn in TURN_SEP.split(block):
        turn = turn.strip()
        if not turn:
            continue
        s = parse_turn(turn)
        q, a, r = s["question"], s["answer"], s["reasoning"]
        if not q or not a:
            continue
        messages.append({"role": "user", "content": q})
        if r:
            messages.append({"role": "assistant",
                             "reasoning_content": r, "content": a})
            reasoning_turns += 1
        else:
            messages.append({"role": "assistant", "content": a})
        total_turns += 1

    if total_turns == 0:
        return None, 0, 0
    return {"messages": messages}, reasoning_turns, total_turns


def txt_to_jsonl(txt_path, out_path, system=None, strict=False):
    with open(txt_path, "r", encoding="utf-8-sig") as f:
        text = f.read()

    dataset = []
    skipped_blocks = 0
    reasoning_turns = 0
    total_turns = 0
    all_reasoning = all_plain = mixed = 0

    for block in BLOCK_SEP.split(text):
        block = block.strip()
        if not block:
            continue
        ex, rt, tt = parse_dialogue(block, system=system)
        if ex is None:
            skipped_blocks += 1
            continue
        dataset.append(ex)
        reasoning_turns += rt
        total_turns += tt
        if rt == tt:
            all_reasoning += 1
        elif rt == 0:
            all_plain += 1
        else:
            mixed += 1

    n = len(dataset)
    turn_pct = (reasoning_turns / total_turns * 100) if total_turns else 0
    dial_pct = (all_reasoning / n * 100) if n else 0

    print(f"Диалогов: {n} (пропущено блоков: {skipped_blocks}).")
    print(f"Реплик: {total_turns}, с reasoning: {reasoning_turns} ({turn_pct:.0f}%).")
    print(f"  - полностью reasoning: {all_reasoning} ({dial_pct:.0f}% диалогов)")
    print(f"  - полностью без reasoning: {all_plain}")
    print(f"  - смешанные: {mixed}")

    if n and dial_pct < 75:
        print(f"⚠️ Диалогов с reasoning {dial_pct:.0f}% (<75%). "
              f"Рекомендуется ≥75%, иначе модель может потерять reasoning.")

    if mixed:
        msg = (f"⚠️ {mixed} смешанных диалогов — reasoning есть не на всех "
               f"репликах. Это противоречивый сигнал (то думай, то не думай). "
               f"Правило 75/25 лучше применять к ЦЕЛЫМ диалогам.")
        if strict:
            print(msg.replace("⚠️", "❌"))
            print(f"Строгий режим: файл {out_path} всё же записан для отладки. "
                  f"Исправьте данные или уберите --strict.")
            sys.exit(2)
        print(msg)

    with open(out_path, "w", encoding="utf-8") as f:
        for item in dataset:
            f.write(json.dumps(item, ensure_ascii=False) + "\n")

    print(f"Сохранено: {out_path}")


def main():
    ap = argparse.ArgumentParser(
        description="Многоходовый txt → jsonl (messages) для Qwen3.8."
    )
    ap.add_argument("txt", help="входной .txt файл")
    ap.add_argument("--system", default=None,
                    help="system-промпт (по умолчанию не добавляется)")
    ap.add_argument("--strict", action="store_true",
                    help="падать (exit 2) на смешанных диалогах")
    ap.add_argument("-o", "--output", default=None,
                    help="путь к .jsonl (по умолчанию рядом с .txt)")
    args = ap.parse_args()

    if not os.path.isfile(args.txt):
        print(f"Ошибка: файл не найден — {args.txt}")
        sys.exit(1)

    out = args.output or (os.path.splitext(args.txt)[0] + ".jsonl")
    txt_to_jsonl(args.txt, out, system=args.system, strict=args.strict)


if __name__ == "__main__":
    main()