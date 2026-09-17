---
name: main-house
description: "Запуск окружения MAIN-HOUSE (сессия tmux с окнами control-center, ollama-logs, work, ollama-cpu) для оркестратора. Модульно: порядок и набор окон задаёт массив MODULES в скрипте MAIN-HOUSE-START."
---

# Main House — модульный запуск окружения оркестратора (ollama)

`MAIN-HOUSE-START` — **единственный вход** во всё окружение. Любой новый
оркестратор просто выполняет `MAIN-HOUSE-START`, и получает готовую сессию
`MAIN-HOUSE` со всеми окнами, каждый уже со своим скриптом. Повторный вызов =
тихий полный перезапуск (окна пересоздаются заново в фиксированном порядке).

## Окна и модули

| idx | окно             | воркер-скрипт        | назначение                          | занят?     |
|-----|------------------|----------------------|-------------------------------------|------------|
| 0   | `control-center` | `enterwatch`         | selfshot, отправка в tmux           | да (поток) |
| 1   | `ollama-logs`    | `ollama-watch`       | живой лог ollama.service            | да (поток) |
| 2   | `work`           | `work`               | интерактивный login-shell           | **нет**    |
| 3   | `ollama-cpu`     | `ollama-cpu`         | модульное окно: TUI с CPU-assistant-cpu (фильтр cpu + Enter) | **нет** (TUI, send-keys можно) |

Окна с потоками (`control-center`, `ollama-logs`) — только чтение через
`capture-pane`, команды не слать. Для `send-keys`: `work` (чистый шелл) и
`ollama-cpu` (интерактивный TUI модели).

## Модульность (приложить / отключить)

Набор и порядок окон = массив в скрипте `MAIN-HOUSE-START`:

```bash
MODULES=(
  "control-center|enterwatch && cd /tmp && tail -f tmux_watch_enter.log"
  "ollama-logs|ollama-watch"
  "work|work"
  "ollama-cpu|ollama-cpu"   # idx 3 — модельное окно (CPU-assistant-cpu)
)
```

* **Приложить** — добавить строку `"имя_окна|команда"` (порядок в массиве = idx).
* **Отключить** — удалить/закомментировать строку.
* Воркеры (`enterwatch`, `ollama-watch`, `work`, `ollama-cpu`) «глупые»: не знают, где
  работают. Все окна и запуски управляет только `MAIN-HOUSE-START`.

## Повторный вызов / перезапуск

`MAIN-HOUSE-START` всегда: убивает старую сессию → создаёт окна заново в порядке
массива → запускает команды (C-c перед каждой). Независимо от того, был ли open
прошлый `main-house`. Вывод — явный список всех окон с процессами.
