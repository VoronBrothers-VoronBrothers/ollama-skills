---
name: ollama-watch
description: "Центр контроля №2: живой поток логов ollama.service (journalctl -u ollama.service -f). Поднимается автоматически в окне MAIN-HOUSE:ollama-logs вместе с main-house."
---

# Ollama-Watch — центр контроля №2, живой лог сервера ollama

Одно из окон окружения `MAIN-HOUSE`: бесконечный поток логов сервиса
`ollama.service` в реальном времени. Скрипт сам ничего не знает о tmux —
это просто воркер `journalctl -u ollama.service -f`.

## Запуск

Команда в PATH (`~/.local/bin/ollama-watch`). Вручную:

```bash
ollama-watch
```

Нормально же поднимается автоматически: `MAIN-HOUSE-START` сам создаёт окно
`MAIN-HOUSE:ollama-logs` и запускает туда `ollama-watch`. Окно занято потоком —
туда **запрещено** слать `send-keys`, только чтение через `capture-pane`.

## Перезапуск

`MAIN-HOUSE-START` — перезапускает все окна со скриптами заново, независимо от
того, был ли open прошлый main-house. Окно `ollama-logs` пересоздаётся и журнал
идёт с нуля. Отключить модуль = удалить строку `ollama-logs|ollama-watch` из
массива `MODULES` в скрипте `MAIN-HOUSE-START`.
