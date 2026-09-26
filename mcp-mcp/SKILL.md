---
name: mcp-mcp
description: Custom TUI fork has built-in MCP (stdio + streamable HTTP) via ~/.ollama/mcp.json. Hot reload без рестарта через /mcp reload (ветка feat/hot-reload-skills-mcp, бинарник 0.34.6-voron-hotreload+). Готовые конфиги в docs/<server_name>/mcp.json.
---

# MCP — напоминание

В кастомном бинарнике ollama встроена функция MCP: серверы подключаются по `~/.ollama/mcp.json` (stdio-команда или URL). **Поддержка hot reload**: `/mcp` — список серверов, `/mcp reload` — переподключение без рестарта TUI; tools/system prompt обновляются, чат-контекст сохраняется. Формат конфига и тесты — в `docs/MCP.md`.

## Куда слать `/mcp reload`

**В СВОЮ сессию оркестратора**, окно 0 (там запущен мой TUI с MCP). Не в MAIN-HOUSE, не искать по tmux ls — цель фиксированная:

```
TGT=orchestrator-this-is-your-own-tmux-send-pictures-here-with-task:0.0
    tmux send-keys -t -N 10 "$TGT" Escape && sleep 0.2 \
    && tmux send-keys -t "$TGT" "/mcp reload" Enter
```

Это `send-keys` из bash-tool (дочерний процесс моего TUI) в мою же панель → TUI принимает `/mcp reload`. Сессия одна и всегда та (имя каноническое). Если вдруг имя поменялось — своя панель = та, где `pane_current_command=ollama`, это я; найти свою: `tmux list-panes -s -F '#{session_name} win=#{window_index} pane=#{pane_id} cmd=#{pane_current_command}' | grep 'cmd=ollama'` (я = окно с `cmd=ollama` в оркестраторской сессии; у меня одно окно → цель `<сессия>:0.0`).

> Не слать в окна MAIN-HOUSE (`control-center`, `ollama-cloud`, `ollama-cpu`) — это другие агенты; reload им, если нужен, идёт аналогично на их панели (`MAIN-HOUSE:3.0`=cloud, `MAIN-HOUSE:4.0`=cpu).

## Готовые конфиги

В `docs/<имя_сервера>/mcp.json` лежат готовые серверные конфиги (`google-chrome`, `prizrak-box`). Не пиши mcp.json с нуля — бери готовый из нужной папки. Проверь пути в args на актуальность (в prizrak-box был битый путь от старой структуры skills/mcp).

## Порядок работы

1. **До работы**: скопировать нужный `docs/<сервер>/mcp.json` в `~/.ollama/mcp.json`.
2. **Применить** — без рестарта: слать `/mcp reload` в СВОЮ сессию см. раздел «Куда слать /mcp reload» (`tmux send-keys -t orchestrator-…:0.0 "/mcp reload" Enter`). Атомарная замена пула: новый создаётся, старый закрывается только при успехе. Старый бинарник (до hot-reload) требовал перезапуск TUI после правки файла.
3. **Работа**: агенты видят инструменты сервера в тулз-списке и могут их вызывать (`require_approval` по умолчанию true — запрос подтверждения).
4. **После работы**: удалить `~/.ollama/mcp.json`, затем (опционально) `/mcp reload` — это hot-выгрузка: пустой конфиг отключает все серверы и закрывает их процессы прямо в сессии, контекст сохраняется. Без reload инструменты просто висят до конца текущей сессии; новая стартует без внешних тулз.
