---
name: carbonyl
description: Terminal Chromium browser (Carbonyl) for JS-heavy sites. Use when w3m/webq returns empty or incomplete content (SPA, React, Vue). Renders full pages in terminal via tmux session.
---

# Carbonyl — терминальный браузер на Chromium

## Когда использовать
- Сайт рендерится через JS (React/Vue/SPA) и `webq get` / `w3m -dump` возвращает пустое или обрезанное содержимое.
- Нужно увидеть, что реально показывает страница в браузере.
- Не подходит для быстрого парсинга — Carbonyl тяжёлый (~500 МБ RAM). Для статики и статей сначала пробуй `webq get`.

## Установка (уже выполнена)
- Бинарник: `~/.local/share/carbonyl-0.0.3/carbonyl` (ELF x86-64, ~151 МБ + shared libs).
- Ссылка в PATH: `~/bin/carbonyl`.
- Версия: v0.0.3 (releases fathyb/carbonyl на GitHub).

## Запуск (обязательно через tmux)

Carbonyl — интерактивный TUI, не работает с piped stdout. Только в tmux-сессии.

```bash
# Запустить сессия carbonyl для URL
tmux kill-session -t carbonyl 2>/dev/null
tmux new-session -d -s carbonyl -x 160 -y 40 \
  "carbonyl --no-sandbox <URL>"

# Подождать загрузки (~3-5 сек) и снять контент
sleep 4
tmux capture-pane -t carbonyl -p
```

### Флаги

| Флаг | Что делает | Пример |
|------|-----------|--------|
| `--no-sandbox` | **Обязателен** — Chromium SUID sandbox недоступна на этом ядре, без флага падает с FATAL | `carbonyl --no-sandbox URL` |
| `-b` / `--bitmap` | Рендер в bitmap-режиме (Unicode блоки ▄ вместо ASCII) — красивее, но тяжелее | `carbonyl -b --no-sandbox URL` |
| `-f <n>` | FPS обновления (по умолчанию 60) | `carbonyl -f 10 --no-sandbox URL` |
| `-z <n>` | Зум страницы (по умолчанию 1.0) | `carbonyl -z 0.8 --no-sandbox URL` |
| `-d` / `--debug` | Режим отладки Chromium | — |

### Прочие Chromium-флаги
Carbonyl принимает стандартные флаги Chromium: `--window-size=1200,900`, `--user-data-dir=/tmp/chrome-carbonyl`, и т.д.

## Взаимодействие с сессией

```bash
# Контент страницы (видимый экран)
tmux capture-pane -t carbonyl -p

# Прокрутка / навигация — отправлять клавиши:
tmux send-keys -t carbonyl "Tab"          # фокус на ссылку
tmux send-keys -t carbonyl Enter           # открыть активную ссылку
tmux send-keys -t carbonyl PageDown        # скролл вниз
tmux send-keys -t carbonyl Escape          # снять фокус
tmux send-keys -t carbonyl q               # выход из карбонила

# Проверить что живёт
pgrep -f "carbonyl --no-sandbox" && echo жив || echo мёртв
```

## Очистка / перезапуск

```bash
tmux kill-session -t carbonyl 2>/dev/null   # закрыть сессию
# если процесс завис:
pkill -f "carbonyl.*--no-sandbox"           # убить все процессы карбонила
```

## Ограничения и заметки

- **Окно tmux** фиксированного размера (160×40 по умолчанию). Carbonyl подстраивается под размер терминала при старте. Чтобы изменить — перезапустить сессию с другими `-x -y`.
- **Сессия может гаснуть** через несколько секунд после загрузки если процесс получает SIGTERM/SIGHUP из tmux. Не критично: контент уже в скроллбеке, можно снять до завершения процесса. Если процесс умер — `tmux capture-pane` всё равно покажет последний кадр.
- **RAM ~500 МБ** на запуск (Chromium + GPU process). Для лёгкой работы хватает.
- **Не интерактивный**: для парсинга/поиска текста удобнее снять контент через `capture-pane -p` и обработать в bash, чем пытаться «листать» карбонил из агента.

## Быстрый сценарий (копипаст)

```bash
# 1. Убить старый
tmux kill-session -t carbonyl 2>/dev/null; pkill -f "carbonyl.*--no-sandbox" 2>/dev/null; sleep 0.5

# 2. Запустить
tmux new-session -d -s carbonyl -x 160 -y 40 \
  "carbonyl --no-sandbox https://example.com"; sleep 4

# 3. Снять содержимое (без ASCII-блоков ▄ для чистого текста)
tmux capture-pane -t carbonyl -p | grep -v "^▄" | head -50

# 4. Убить когда не нужен
tmux kill-session -t carbonyl 2>/dev/null; pkill -f "carbonyl.*--no-sandbox" 2>/dev/null
```

## Когда НЕ использовать Carbonyl
- Статичные HTML: `webq get <url>` быстрее и легче.
- API/JSON: прямой curl или `webq get`.
- Быстрый поиск ссылок: `webq top 'запрос' 5`.
