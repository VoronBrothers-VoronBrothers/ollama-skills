---
name: webq
description: Local web search and page reading via terminal (w3m + DuckDuckGo) with no API keys. Use when the AI needs to search the internet, fetch a webpage's text, or find links — e.g. "look up X online", "check current version", "read this URL".
---

# Web search & page reading from terminal (webq)

Primary tool: `~/.local/bin/webq` (bash, zsh-compatible). Falls back to raw `w3m -dump` if webq is missing.

## Commands

- `webq top 'запрос' [N]` — N result URLs only (default 3), one per line, no protocol. Best for picking a source.
- `webq search 'запрос'` — full result dump: title → `● domain/path` → snippet.
- `webq get <URL>` — page text (clean, links as `[text]`, images as `[file]`).
- Chain: `url=$(webq top "query" 1); webq get "$url"`

## Rules & pitfalls

- Always quote the query; URLs may contain `&`, quotes.
- If `top` output is only trending links (wikipedia number articles, TV channels), the query was empty or mangled — check the URL before retrying.
- DDG bot-check: `curl` to html/lite.duckduckgo.com returns HTTP 202 (challenge) — use w3m, it passes. Public SearXNG JSON instances usually return 429.
- Some sites (e.g. github.com) make `w3m -dump` fail with `gzip: stdin: not in gzip format`. `webq get` already auto-falls back to `lynx -dump`; for raw calls use lynx directly on those sites.
- JS-rendered sites (e.g. gismeteo.ru): HTML dump has structure but no dynamic data (temperatures, prices). Prefer their JSON API endpoints — `webq get` works fine on plain JSON URLs too (e.g. api.open-meteo.com).
- Long pages: pipe through `head -n 200` or grep for keywords; don't dump a whole page into context.
- Verify fast-changing facts (versions, dates) with at least 2 independent results before answering.

## Fallback without webq

```bash
w3m -dump "https://html.duckduckgo.com/html/?q=$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(" ".join(sys.argv[1:])))' q1 q2)"
w3m -dump "https://example.com"   # any page (if gzip error → lynx -dump)
```

## Cleanup habit

Do not leave fetched files in cwd; use `/tmp` if saving. `w3m -dump` prints to stdout only, no cache files needed.
