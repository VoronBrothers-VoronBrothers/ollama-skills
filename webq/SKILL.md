---
name: webq
description: Use before task. Terminal web search + page fetch (DDG/Bing via curl), no API keys. Default for internet search.
---

# Web search & page reading from terminal (webq)

Primary tool: `~/.ollama/skills/webq/scripts/webq` (bash). Works in fresh sessions, no setup.

## Commands

- `webq top 'запрос' [N]` — N result URLs only (default 10), one per line, with `https://`. Best for picking a source: `url=$(webq top "query" 1)`.
- `webq search 'запрос' [N]` — full dump: Title / ● URL / snippet.
- `webq get <URL>` — page text (elinks → lynx → w3m, first that returns ≥80 chars). Scheme optional (`en.wikipedia.org/wiki/X` auto-gets `https://`).
- N can be given as the last argument: `webq top "biceps anatomy" 5`.

## Search chain & known degradation (datacenter IP)

- Engine order: DuckDuckGo html (2 attempts, 8 s pause) → Bing RSS en-US (clean XML with real links).
- From this IP both engines can be **bot-walled intermittently**: DDG answers an "anomaly" challenge page; then Bing returns *stale unrelated results* (e.g. Wikipedia articles about the number 4, Microsoft pages for anatomy queries) — recognize garbage by titles not matching the query. When that happens: wait a few minutes and retry, or use the MCP browser tool (`skill mcp`).
- Public SearXNG JSON instances, Mojeek, Ecosia, Yahoo are also blocked/202 from this IP — don't burn time on them.
- w3m cannot talk TLS to DuckDuckGo (built-in libssl mismatch) — use curl/elinks for pages; webq already does.

## Rules & pitfalls

- Always quote the query.
- If `top` returns URLs that look unrelated to the query, it's engine degradation (above), not a parsing bug — don't retry rapidly (re-triggers rate limits); wait ≥60 s.
- JS-rendered sites (gismeteo etc.): HTML dump has no dynamic data — prefer their JSON API endpoints; `webq get` works on plain JSON URLs too.
- Long pages: pipe through `head -n 200` or grep for keywords.
- Verify fast-changing facts with ≥2 independent results.

## Fallback without webq

```bash
curl -sA "Mozilla/5.0" "https://html.duckduckgo.com/html/?q=$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(" ".join(sys.argv[1:])))' q1 q2)" | elinks -dump
elinks -dump URL   # page text (lynx -dump as last resort)
```

## Cleanup habit

Do not leave fetched files in cwd; use `/tmp` if saving. Scripts print to stdout only, no cache.
