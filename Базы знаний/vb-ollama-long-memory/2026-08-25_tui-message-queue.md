# Ollama: очередь сообщений в TUI (нативный патч)

Дата: $(date +'%Y-%m-%d %H:%M')

## Факт
В TUI-режиме ollama (bare `ollama`, не `run`) сообщения, отправленные пока модель пишет, больше не выбрасываются — встают в очередь и отправляются по одному после каждого ответа. Патч в исходниках `ollama 0.33.0-rc3` (каталог "GitHub ollama"), собран в `/usr/local/bin/ollama`.

## Правки (3 файла, видны в `git diff`)
1. `cmd/tui/chat/chat.go`:
   - поле `pendingPrompts []string` в структуре chatModel;
   - в обработчике `chatRunDoneMsg` перед `m.status = "ready"`: если очередь не пуста — сдвинуть первое сообщение и `return m.startRun(next)`.
2. `cmd/tui/chat/input.go`:
   - в `handleSubmit()` блок `(m.running || m.compacting)` вместо "wait for current response" теперь делает `m.pendingPrompts = append(...)`, статус `queued (N)`, очищает input.
3. `cmd/tui/chat/render.go`:
   - в `notificationLine()`: если очередь не пуста, показывать `queued (N): <первое сообщение, обрезка 40 символов>`.

## Как повторить / пересобрать
```
cd "/home/voron/Документы/VB-ollama/GitHub ollama/ollama 0.33.0-rc3"
sudo go build -o /usr/local/bin/ollama .
```
Важно: патченный бинарник должен быть как `/usr/local/bin/ollama` — сессия берёт binary по имени `ollama`, а не ollama-queue.

## Откат
- Бэкап бинарника без TUI-очереди: `/usr/local/bin/ollama.bak-20260825-pre-queue`.
- Откат кода: `git checkout cmd/tui/chat/chat.go cmd/tui/chat/input.go cmd/tui/chat/render.go` (вместе с этим потеряется очередь, но останутся другие локальные правки в репо — interactive.go и т.д.).

## Проверено
2026-08-25: пользователь подтвердил — работает: второе сообщение во время генерации встаёт в очередь и отправляется после ответа.

## Связано
- Скриптовый аналог (xdotool, `/tmp/selfqueue.txt`): `/home/voron/Документы/VB-ollama/Скрипты_ИИ/очередь_сообщений.sh` — теперь не нужен для этого сценария.
- `cmd/interactive.go` патч (goroutine+channel для `ollama run` режима) остался как есть, он другой путь.
