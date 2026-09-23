---
name: main-house
description: "Запуск окружения MAIN-HOUSE (сессия tmux с окнами control-center, ollama-logs, work, ollama-cloud, ollama-liquid) для оркестратора. Модульно: порядок и набор окон задаёт массив MODULES в скрипте MAIN-HOUSE-START."
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
| 3   | `ollama-cloud`     | `ollama-cloud`         | модульное окно: TUI с gemma4:31b-cloud (фильтр cloud + Enter) | **нет** (TUI, send-keys можно) |
| 4   | `ollama-liquid`    | `ollama-liquid`        | liquid-окно: TUI с LFM (фильтр CPU-assistant-liquid); state держится между ходами | **нет** (TUI, send-keys можно) |

Окна с потоками (`control-center`, `ollama-logs`) — только чтение через
`capture-pane`, команды не слать. Для `send-keys`: `work` (чистый шелл),
`ollama-cloud` и `ollama-liquid` (интерактивные TUI моделей).

## Модульность (приложить / отключить)

Набор и порядок окон = массив в скрипте `MAIN-HOUSE-START`:

```bash
MODULES=(
  "control-center|enterwatch && cd /tmp && tail -f tmux_watch_enter.log"
  "ollama-logs|ollama-watch"
  "work|work"
  "ollama-cloud|ollama-cloud"   # idx 3 — модельное окно: gemma4:31b-cloud (фильтр cloud + Enter)
  "ollama-liquid|ollama-liquid cpu-assistant-liquid"   # idx 4 — liquid-окно: LFM, фильтр CPU-assistant-liquid
)
```

* **Приложить** — добавить строку `"имя_окна|команда"` (порядок в массиве = idx).
* **Отключить** — удалить/закомментировать строку.
* Воркеры (`enterwatch`, `ollama-watch`, `work`, `ollama-cpu`,
  `ollama-cloud`, `ollama-liquid`) «глупые»: не знают, где
  работают. Все окна и запуски управляет только `MAIN-HOUSE-START`.

## Чтение ответа помощника (окна ollama-cloud / ollama-liquid)

Конец хода определяется строкой маркера вида:

```
⏹ остановка: спец-символ • prompt N (кэш M) • out K • разм. X
```

* Числа N/M/K/X меняются от ответа к ответу — опираться на сам факт
  появления строки, а не на конкретные значения.
* **Важный сценарий**: модель может вылететь/зависнуть БЕЗ этой строки
  (ошибка генерации, тайм-аут). Тогда считать ответ незавершённым,
  проверить кадр (`capture-pane`) и при необходимости повторить запрос.
* Для liquid-окна `/new` между ходами не обязателен: LFM держит своё
  состояние между вызовами; чистим контекст только по желанию (для
  читаемости транскрипта).

## Повторный вызов / перезапуск

`MAIN-HOUSE-START` всегда: убивает старую сессию → создаёт окна заново в порядке
массива → запускает команды (C-c перед каждой). Независимо от того, был ли open
прошлый `main-house`. Вывод — явный список всех окон с процессами.
