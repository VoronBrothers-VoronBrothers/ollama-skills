#!/usr/bin/env python3
"""Ask Perplexity (sonar) and print the answer with source links, saving each Q&A to knowledge.

Credentials are found automatically:
  1. env PERPLEXITY_API_KEY (+ optional PLX_BASE_URL), else
  2. ~/.ollama/providers.json — first provider that lists a `perplexity/*` model.

Every question+answer (with sources) is saved as markdown under
~/.ollama/knowledge/perplexity/ in the same format as other knowledge folders,
so it gets indexed and searchable later. Disable with --no-save.

Usage:
  plx.py "your question"            # one-shot answer + sources (auto-saved)
  plx.py "your question" --n 5      # cap the number of shown sources
  plx.py "your question" --json     # dump the full raw JSON response
  plx.py "your question" --no-save  # do not write to knowledge
  python3 plx.py                     # interactive multi-turn chat (exit/Ctrl-D)

Stdlib only. No network library required beyond urllib.
"""
import argparse
import datetime as _dt
import json
import os
import re
import sys
import urllib.request


KNOWLEDGE_DIR = os.path.expanduser("~/.ollama/knowledge/perplexity")


def find_credentials():
    """Return (base_url, api_key, model). Raises SystemExit if none found."""
    env_key = os.environ.get("PERPLEXITY_API_KEY")
    base_env = os.environ.get("PLX_BASE_URL")
    if env_key:
        return (base_env or "https://api.perplexity.ai").rstrip("/"), env_key, "sonar"

    path = os.path.expanduser("~/.ollama/providers.json")
    try:
        with open(path) as f:
            data = json.load(f)
    except Exception:
        raise SystemExit("нет ни PERPLEXITY_API_KEY в окружении, ни ~/.ollama/providers.json")

    for prov in data.get("providers", []):
        if any(m.lower().startswith("perplexity") for m in prov.get("models", [])):
            return prov["base_url"].rstrip("/"), prov["api_key"], "perplexity/sonar"

    raise SystemExit(
        "не найден провайдер perplexity в providers.json; задайте PERPLEXITY_API_KEY"
    )


def ask(base, key, model, messages):
    req = urllib.request.Request(
        f"{base}/chat/completions",
        data=json.dumps({"model": model, "messages": messages, "stream": False}).encode(),
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
        },
    )
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.load(r)


def extract_sources(message):
    """Pull url_citation annotations out of the assistant message."""
    out = []
    seen = set()
    for a in message.get("annotations") or []:
        if a.get("type") != "url_citation":
            continue
        u = a["url_citation"]["url"]
        if u not in seen:
            seen.add(u)
            out.append((u, a["url_citation"].get("title", "")))
    return out


def _slug(text, maxlen=70):
    text = re.sub(r"[^\w]+", "_", text.strip(), flags=re.UNICODE).strip("_")
    return (text[:maxlen] or "вопрос").rstrip("_")


def save_entry(question, answer, sources, model="perplexity/sonar"):
    """Write Q&A to knowledge/perplexity in the standard markdown format. Returns path."""
    os.makedirs(KNOWLEDGE_DIR, exist_ok=True)
    now = _dt.datetime.now().astimezone()
    ts = now.isoformat(timespec="seconds")
    fname = f"{now:%Y-%m-%d-%H%M%S}_{_slug(question)}.md"
    path = os.path.join(KNOWLEDGE_DIR, fname)

    lines = [
        f"# {_slug(question, maxlen=120)}",
        "",
        f"> создано: {ts} · изменено: {ts}",
        "",
        "**Пользователь:**",
        "",
        question.strip(),
        "",
        f"**AI (Perplexity sonar):**",
        "",
        answer.strip(),
    ]
    if sources:
        lines += ["", "---", "Источники:"]
        for i, (u, t) in enumerate(sources, 1):
            lines.append(f"[{i}] {t} — <{u}>" if t else f"[{i}] <{u}>")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    return path


def render(data, limit=None):
    msg = data["choices"][0]["message"]
    answer = (msg.get("content") or "").strip()
    print(answer)
    sources = extract_sources(msg)
    if not sources:
        return answer, []
    total = len(sources)
    shown = sources[:limit] if limit else sources
    print(f"\n--- Источники ({len(shown)} из {total}) ---")
    for i, (u, t) in enumerate(shown, 1):
        if t:
            print(f"[{i}] {t}\n    {u}")
        else:
            print(f"[{i}] {u}")
    return answer, sources


def main():
    p = argparse.ArgumentParser(description="Ask Perplexity with source links (auto-saves to knowledge)")
    p.add_argument("question", nargs="*", help="вопрос (пусто = интерактивный чат)")
    p.add_argument("--n", type=int, default=None, help="не показывать больше N ссылок")
    p.add_argument("--json", action="store_true", help="вывести сырой JSON целиком")
    p.add_argument("--no-save", action="store_true", help="не сохранять в knowledge/perplexity")
    p.add_argument("--model", default=None, help="переопределить модель (по умолчанию sonar)")
    args = p.parse_args()

    base, key, model = find_credentials()
    if args.model:
        model = args.model
    save_enabled = not args.no_save and not args.json

    messages = []
    if args.question:
        q = " ".join(args.question).strip()
        data = ask(base, key, model, [{"role": "user", "content": q}])
        if args.json:
            print(json.dumps(data, ensure_ascii=False))
            return
        answer, sources = render(data, limit=args.n)
        if save_enabled:
            path = save_entry(q, answer, sources, model=model)
            print(f"\n💾 сохранено в знания: {path}")
    else:
        print("Чат с Perplexity sonar. Введите вопрос (exit/Ctrl-D — выход).\n")
        while True:
            try:
                q = input("вы> ").strip()
            except EOFError:
                break
            if not q or q.lower() in ("exit", "quit", "выход"):
                break
            messages.append({"role": "user", "content": q})
            data = ask(base, key, model, messages)
            if args.json:
                print(json.dumps(data, ensure_ascii=False))
                return
            answer, sources = render(data, limit=args.n)
            if save_enabled:
                path = save_entry(q, answer, sources, model=model)
                print(f"💾 сохранено в знания: {path}")
            messages.append({"role": "assistant", "content": answer})


if __name__ == "__main__":
    main()
