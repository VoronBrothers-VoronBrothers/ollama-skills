---
name: main-house
description: "Запуск окружения MAIN-HOUSE (сессия tmux с окнами control-center и work) для оркестратора. Выполнить в начале каждого запуска."
---

# Main-House — запуск окружения оркестратора

Одна команда готовит tmux-окружение: создаёт сессию `MAIN-HOUSE` (если ещё нет)
с окнами `control-center` и `work`, поднимает enterwatch и лог.

## Запуск

Команда в PATH (`~/.local/bin/MAIN-HOUSE-START`). Просто:

```bash
MAIN-HOUSE-START
```

Скрипт сам: создаёт сессию при отсутствии → шлёт в control-center `enterwatch && tail -f tmux_watch_enter.log`.

## Режим окон (важно)

| Окно | Назначение | Правила |
|---|---|---|
| `MAIN-HOUSE:control-center` (idx 0) | enterwatch + логи | **Запрещено** отправлять туда любые команды через `send-keys`. Только чтение `capture-pane`. |
| `MAIN-HOUSE:work` (idx 1) | интерактивная работа | Свободно. |

- Одна задача → одно окно: `tmux new-window -t MAIN-HOUSE -n "имя"`; завершился — `tmux kill-window -t MAIN-HOUSE:имя`.
- Одноразовые команды (curl, утилиты, чтение других логов) выполнять в локальном bash, не заходя в сессию.
