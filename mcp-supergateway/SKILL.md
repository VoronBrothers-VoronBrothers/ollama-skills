---
name: mcp-supergateway
description: "Энтрипоинт для поднятия MCP-серверов по HTTP через supergateway. Даёт возможности, которых нет в bash: управление браузером, работа с файлами, видео."
---

# MCP SuperGateway

Поднимает stdio-MCP сервер наружу по HTTP (streamableHttp), чтобы обращаться к нему через curl из bash.

## Зачем

У меня есть bash. MCP нужен для **других способностей**:
- браузер (кликать, скриншоты, парсинг) → `server-puppeteer`
- файлы как сервис → `server-filesystem`
- видео-монтаж → kdenlive server

**mcp-shell не использовать** — это обёртка над bash.

## Серверы

| Сервер | Команда stdio | Порт | stateful? |
|--------|---------------|------|-----------|
| puppeteer | `npx -y @modelcontextprotocol/server-puppeteer` | 8810 | да |
| filesystem | `npx -y @modelcontextprotocol/server-filesystem /home/voron` | 8812 | нет |
| kdenlive | `/home/voron/mcp-kdenlive/.venv/bin/python /home/voron/mcp-kdenlive/server.py` | 8815 | нет |

## Запуск

### Приоритет #1: tmux-сессия (без nohup)

Каждый сервер — отдельная сессия. Лог виден вживую, можно ctrl+c и перезапустить.

```bash
# Создать сессию и запустить
tmux new-session -d -s mcp-puppeteer -x 200 -y 50
tmux send-keys -t mcp-puppeteer \
  "export PUPPETEER_LAUNCH_OPTIONS='{\"headless\":false,\"args\":[\"--no-sandbox\"]}' && export ALLOW_DANGEROUS=true && npx -y supergateway --stdio \"npx -y @modelcontextprotocol/server-puppeteer\" --port 8810 --cors --outputTransport streamableHttp --stateful" \
  Enter

# Filesystem
tmux new-session -d -s mcp-filesystem -x 200 -y 50
tmux send-keys -t mcp-filesystem \
  "npx -y supergateway --stdio \"npx -y @modelcontextprotocol/server-filesystem /home/voron\" --port 8812 --cors --outputTransport streamableHttp" \
  Enter

# Kdenlive
tmux new-session -d -s mcp-kdenlive -x 200 -y 50
tmux send-keys -t mcp-kdenlive \
  "npx -y supergateway --stdio \"/home/voron/mcp-kdenlive/.venv/bin/python /home/voron/mcp-kdenlive/server.py\" --port 8815 --cors --outputTransport streamableHttp" \
  Enter
```

### Вариант #2: nohup (без tmux)

Когда не нужен доступ к логу или много серверов одновременно:

```bash
nohup npx -y supergateway \
  --stdio "<команда-сервера>" \
  --port <порт> --cors --outputTransport streamableHttp [--stateful] \
  > /tmp/sgw-<имя>.log 2>&1 &
```

### Проверка (оба варианта)

Ждать 10–15 сек (npx качает). Проверка: `ss -tlnp | grep <порт>`

## Протокол MCP по HTTP

### Заголовки для каждого запроса

```
Content-Type: application/json
Accept: application/json, text/event-stream
mcp-session-id: <id>       ← только в stateful-режиме, после initialize
```

### Шаг 1: initialize → получить session id (stateful)

```bash
RESP=$(curl -s -i -X POST http://localhost:8810/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"bash","version":"1.0"}}}')

SESSION=$(echo "$RESP" | grep -i mcp-session-id | tail -1 | awk '{print $2}' | tr -d '\r')
```

Для non-stateful серверов (filesystem, kdenlive) session id не нужен — можно сразу tools/call.

### Шаг 2: tools/list — увидеть инструменты

```bash
curl -s -X POST http://localhost:<порт>/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  [-H "mcp-session-id: $SESSION"] \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
```

### Шаг 3: tools/call — выполнить действие

```bash
curl -s -X POST http://localhost:<порт>/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  [-H "mcp-session-id: $SESSION"] \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"<инструмент>","arguments":{...}}}'
```

### Ответ — SSE-поток

```
event: message
data: {"result":...,"jsonrpc":"2.0","id":N}
```
Данные в строках `data:` — это JSON.

## Особенности серверов

Папка с именем сервера содержит рабочие примеры и приёмы:
- `wikipedia/NOTES.md` — поиск, парсинг статей (puppeteer)
- `qwen/NOTES.md` — логин, отправка; блокируется антиботом (puppeteer)
- `kdenlive/NOTES.md` — инструменты, примеры build_project, рендер

## Остановка

```bash
# tmux:
tmux kill-session -t mcp-puppeteer

# nohup: по порту
pkill -f "supergateway.*8810"
```

## Замечания

- `--stateful` обязателен для puppeteer (иначе каждый запрос = новый браузер).
- Порт занят? → сменить `--port`.
- npx первый раз качает 10–15 сек.
- Точные имена инструментов — смотреть в tools/list.
- Session id: `grep -i mcp-session-id | tail -1 | awk '{print $2}'` (первая строка = имя заголовка).
