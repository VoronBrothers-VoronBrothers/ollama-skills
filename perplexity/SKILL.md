---
name: perplexity
description: Ask a question to Perplexity (sonar) and get an answer with source links/citations. Use when you need web-grounded facts, fresh/current information, or want cited sources for an answer — not for local reasoning tasks that other models handle.
---

# Ask Perplexity

Send a question to Perplexity's `sonar` model through the OpenAI-compatible
proxy and print the answer **together with the source links it references**.
This is the web-search tool when you need facts from the live internet plus
citable sources (news, docs, papers), not just recall.

## How to run

The script `scripts/plx.py` finds credentials automatically:
1. env `PERPLEXITY_API_KEY` (+ optional `PLX_BASE_URL`), or
2. `~/.ollama/providers.json` — the provider that lists a `perplexity/*` model.

Run it from this skill directory (paths are relative to the skill dir):

```bash
python3 scripts/plx.py "your question"          # one-shot: answer + sources (auto-saved)
python3 scripts/plx.py "your question" --n 5    # cap shown sources at 5
python3 scripts/plx.py "your question" --json   # full raw JSON response
python3 scripts/plx.py "your question" --no-save# do not write to knowledge
python3 scripts/plx.py                          # interactive multi-turn chat
```

## Auto-saving to knowledge (on by default)

Because each query costs money, every Q&A is saved as markdown under
`~/.ollama/knowledge/perplexity/` in the same format as the other topic folders
(`# title`, `> создано/изменено`, `**Пользователь:**`, `**AI (Perplexity sonar):**`,
then all sources with URLs). Filenames are `<YYYY-MM-DD-HHMMSS>_<slug>.md` so they
sort chronologically. Use `--no-save` to skip saving (e.g. quick throwaway checks).
The full source list is stored, not just the `--n`-capped display.

## Reading the output

- The answer text uses inline markers like `[1][2]`.
- Under `--- Источники ---` is a numbered list of real URLs (and titles) that the
  model used. Show these to the user when they ask for sources, or cite them in your reply.

## Notes / limits

- The proxy zeroes out per-marker positions, so map `[n]` markers to the source
  **list** (position order) rather than expecting an exact 1:1 index match to a URL.
- If you only need the raw payload for further parsing, use `--json`.
- Ask one focused question at a time; batch unrelated questions in separate calls.
