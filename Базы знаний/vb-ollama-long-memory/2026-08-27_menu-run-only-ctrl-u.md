# 27.08 — меню ollama: только «Chat, Code, & Work» + Ctrl+U

## Что сделано
1. **Меню TUI (команда `ollama`)**: в корне остались только пункт
   `Chat, Code, & Work`. Остальные интеграции (claude, opencode, hermes,
   openclaw, More...) из корня убраны.
2. Тесты `cmd/tui/tui_test.go` переписаны под новое поведение (раньше падали).
3. Бинарник пересобран и поставлен в `/usr/local/bin/ollama`.
4. Скилл tmux дополнен: `Ctrl+U` очищает строку ввода в bubbletea-TUI.

## Где правки
- Репозиторий: `/home/voron/Документы/VB-ollama/GitHub ollama and others/ollama 0.33.0-rc3`
- `cmd/tui/tui.go`: функция `buildMenuItems(state, showOthers)` возвращает
  `[]menuItem{runModelMenuItem}` — всё остальное (launcherIntegrationItems,
  otherIntegrationItems, othersMenuItem) больше не добавляется в корневое меню.
- `cmd/tui/tui_test.go`: вместо 8 тестов на интеграции — 4 теста:
  - `TestMenuRendersOnlyRunChoice` — в корне только `run`, в View нет
    "Launch ..."/"More...", есть заголовок и описание run-пункта.
  - `TestMenuNavigationStaysOnRun` — ↑/↓ курсор не сходит с пункта (курсор 0).
  - `TestMenuEnterOnRunSelectsRun`, `TestMenuRightOnRunSelectsChangeRun`.
  - `TestMenuShowsCurrentModelSuffixOnRun` — суффикс `(модель)` у run-строки.

## Как повторить (пересборка)
```bash
cd "/home/voron/Документы/VB-ollama/GitHub ollama and others/ollama 0.33.0-rc3"
go test ./cmd/tui/ -count=1
go build -ldflags "-X github.com/ollama/ollama/version.Version=0.33.0-rc3-voron" -o /tmp/ollama-patched .
sudo mv /tmp/ollama-patched /usr/local/bin/ollama && sudo chmod 755 /usr/local/bin/ollama
```
- `mv`, не `cp` — на занятом бинарнике cp падает.
- Проверка: tmux-сессия `helper` (или любая) → команда `ollama` → меню
  показывает ровно одну строку `▸ Chat, Code, & Work (orchestrator)`.

## Ctrl+U — очистка строки ввода (новое)
- В ollama-TUI (bubbletea) `Ctrl+U` стирает текущую строку ввода.
- Через tmux: `tmux send-keys -t имя C-u`.
- Проверено: набрал `xyz`, C-u → строка пустая.
- **Backspace через tmux send-keys в bubbletea не работает** — кейсы уходят
  текстом ("BackSpace", "Backspace"), а не клавишами. Не гонять по буквам.
- Записано в скилл `/home/voron/.ollama/skills/tmux/SKILL.md` (раздел «Ctrl+U»).

## Заметки
- Ветка репо грязная (много своих правок: agent/tools, cmd, tui/chat) — это
  нормально, полный откат не делался. Откат только меню = `git checkout -- cmd/tui/`.
- Сессия tmux `helper` осталась живой с помощником orchestrator-helper (промпт
  «what changed on this branch?» в строке ввода — не моё, был до).
