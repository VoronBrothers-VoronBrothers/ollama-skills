---
name: websearch
description: Local web search via SearXNG (Docker) — clean JSON results + page fetch for Ollama. Use for fresh/relevant internet data and as primary source of up-to-date facts.
---

# Local web search (SearXNG-backed)

Primary tool: `~/.ollama/skills/websearch/scripts/websearch` (python3). Talks to a local SearXNG instance in Docker — aggregates Google/Bing/DuckDuckGo/Wikipedia/etc., returns clean JSON snippets. More robust and cleaner than scraping HTML directly (see `webq`).

## Commands
- `websearch search '<query>' [N]` — top-N results: `[i] title / URL / snippet`. Default N=5. Last positional number sets N too (`... "query" 4`).
- `websearch get <URL>` — page text (curl → elinks/lynx/w3m). Scheme optional. Pipe to `head -n 200` or grep for keywords on long pages.
- `websearch check` — verify SearXNG is up and JSON format is enabled. Run first if a search fails.

### Useful flags (search)
- `-n, --num N` — how many results.
- `--category CAT` — `general`(default), `news`, `science`, `it`, `images`, etc.
- `--time-range day|month|year` — freshness filter. **Use for "latest/свежие" queries.**
- `--lang auto|en|ru|...`
- `--json` — raw JSON (title/url/content/engine) instead of formatted text.

Env: `SEARXNG_URL` overrides endpoint (default `http://127.0.0.1:8888`).

## Prerequisite: the SearXNG container must be running
Deploy files live in the project folder:
`~/Документы/VB-ollama/Базы знаний/Цели-Проекты/Поисковик для локальных ИИ/deploy/`

```bash
cd "/home/voron/Документы/VB-ollama/Базы знаний/Цели-Проекты/Поисковик для локальных ИИ"
docker compose -f deploy/docker-compose.yml up -d   # start (pulls image on first run)
docker compose -f deploy/docker-compose.yml down    # stop
```

If `websearch search` says "SearXNG недоступен", just run the `up -d` line above and retry.

## Rules & pitfalls
- **HARD RULE — date anchor (обязательно):** Перед КАЖДЫМ поиском вставь в запрос текущий ГОД (а для «свежих»/новостей — месяц+число), чтобы (1) модель не теряла из виду, какая сейчас дата, и (2) поисковик отдавал актуальные данные. Реальную дату бери из своего системного контекста («Current date: …»). Примеры: `gpu prices 2026` (а не просто `gpu prices`), `election results November 2026`. Для новостей/свежести добавь `--time-range day|month`.
- Always quote the query.
- For fresh/time-sensitive facts add `--time-range month` (or day/year). Verify with ≥2 independent results before stating fast-changing facts as true.
- SearXNG uses the host's datacenter IP to hit upstream engines, so individual engines can still get bot-walled — but aggregation across many engines makes it far more reliable than a single-engine scrape. If results look empty/garbage, retry once; if still bad, fall back to `webq` or the MCP browser (`skill mcp`).
- JS-rendered sites: `get` returns mostly nav text for them. Prefer JSON API endpoints when available (works great with `get`).
- Long pages: `| head -n 200` or grep keywords. Don't dump whole megapages into context.

## When to prefer which tool
- **websearch** → structured results + freshness filtering, primary default for research/fresh data.
- **webq** → quick one-off search or page fetch when the SearXNG container isn't up (no Docker needed).
- **mcp-supergateway** → full browser automation (clicks/forms/JS) when a static fetch isn't enough.
