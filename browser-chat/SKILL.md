---
name: browser-chat
description: Browser chat automation for DeepSeek (Дипсик / chat.deepseek.com) via scripts — open a URL from file, deterministically sized Chrome, type and submit a question, capture long answers. ЧТЕНИЕ ОТВЕТА = копирование по ЗРЕНИЮ (скрин → оркестратор видит кнопку Copy → клик → буфер). Use when the user asks to ask something to Дипсик/DeepSeek («задай вопрос дипсику»), ask in a web chat/browser, automate a browser session, or use DeepSeek as a FALLBACK INTERNET SEARCH (see below) when web_search/web_fetch/webq are unavailable.
---

# Browser chat automation

All scripts live in `/home/voron/Документы/VB-ollama/Скрипты_ИИ/browser_chat/`. Scripts are tested and working; prefer running them over re-inventing with xdotool.

## Full cycle (main entry point)

```bash
cd /home/voron/Документы/VB-ollama/Скрипты_ИИ/browser_chat
./full_cycle.sh "<question>" [WAIT_SECONDS=12]
```

Does: auto-start Chrome if not running (`setsid google-chrome https://chat.deepseek.com/`, polls ≤20 s) → New chat → activate window → click input → clear (`ctrl+a Delete`) → type → Enter → wait → scroll_capture → saves to `sessions/<timestamp>/` (question.txt, full.png, meta.json, frames).

## Чтение ответа (ПРИОРИТЕТ — скопированный текст)

**АВТОКОПИИ НЕТ.** Скрипт не ищет кнопку сам: оркестратор смотрит скриншот, находит кнопку Copy глазами и сам задаёт координаты клика. Работает с любым браузерным ИИ (DeepSeek сегодня, GPT/Claude/Яндекс завтра) — зрение не зависит от темы, языка и разметки.

```bash
./copy_vision.sh shot            # окно на 0,0 + скролл вниз → скрин → картинка улетает тебе (следующий turno)
./copy_vision.sh click X Y [out] # клик в экранных X,Y → буфер → out (дефолт /tmp/deepseek_answer.md)
```

Поток:
1. `copy_vision.sh shot` — картинка прилетает в твоём следующем сообщении.
2. Смотри: под последним ответом ряд иконок, Copy = две наложенные квадратики (самая левая). Пиксели скриншота = координаты мыши (Chrome на 0,0) — целишься напрямую по картинке.
3. `copy_vision.sh click X Y` → ответ в `/tmp/deepseek_answer.md`, отчёт пользователю строишь по ТЕКСТУ.
4. Промашил (FAIL / буфер <50 B / мусор): ещё один shot → переприцелься.

Скрипт сам делает: размер окна, фокус Chrome, очистку буфера ПЕРЕД кликом (stale невозможно), проверку размера/мусора в буфере, возврат фокуса в Konsole.

## Individual scripts

| Script | Purpose |
|---|---|
| `full_cycle.sh <Q> [WAIT]` | New chat → typing → Enter → wait → scroll_capture → sessions/. (см. выше) |
| `copy_vision.sh shot \| click X Y [out]` | Vision-copy: скрин оркестратору, затем клик по заданным координатам + чтение буфера. |
| `win_fix.sh [W=1920] [H=1024]` | Move/resize the chat Chrome window to 0,0 W×H. Matches EXACT WM_CLASS `google-chrome`. |
| `open_url.sh <file-or-url>` | Open URL (or file in `urls/*.txt`) in existing browser. |
| `scroll_capture.sh <session-dir>` | Multi-frame scroll capture → stitched `full.png` + frame_NNN.png. Stops on md5 frame repeat or 30-frame cap. |
| `save_session.sh <question> <screenshot>` | Save question + image + meta.json into a session dir (utility). |
| `archive/` | Устаревшая автокопия: copy_answer.sh + detect_copy_row.py (пиксельные эвристики, координаты устаревают). Не использовать — только vision-flow. |

## Key facts (learned, do not re-derive)

- **Two Chrome instances exist.** The chat browser is WM_CLASS exactly `google-chrome`; Prizrak-box VPN is `google-chrome-stable`. Never match by substring.
- **Focus before every input:** `xdotool windowactivate --sync $WIN` must precede each keystroke/click sequence or it lands in Konsole. copy_vision.sh/copy full_cycle handle this; any manual xdotool chain — remember the rule and call `../focus_consolidate.sh` after.
- **Input coordinates** (window at 0,0, 1920×1024): New chat ≈ (93,213); input field ≈ (960,570). Scroll cursor must be at (960,400) so wheel targets content area.
- **Copy-icon row**: под каждым ответом ряд иконок: copy — самая левая (две наложенные квадратики), затем refresh/like/dislike/share с шагом ≈ +42/+77/+110/+142 px. Y зависит от длины ответа — бери только из актуального скрина, не из памяти.
- **НЕ кликай Copy в шапке код-блоков** (правый верх угла блока «bash/python»): он копирует ТОЛЬКО код, а не весь ответ. Симптом: буфер ~400–500 B при длинном ответе → цель была код-блок, переприцеливайся на иконки под текстом ответа.
- **Clipboard hygiene:** буфер чистится перед каждым copy-кликом (`xclip < /dev/null`) — иначе stale-контент (старый ответ, путь к файлу) тихо проходит за «ответ». copy_vision.sh делает сам; ручной клик — помни.
- **Chrome runs WITHOUT `--remote-debugging-port`** — CDP not available; text extraction is vision/copy only.
- **Screenshots:** `spectacle -b -f -o <file>` → полный 1920×1080, пиксели = экранные координаты.
- **Self-vision loop:** `show_image.sh <img> [konpid]` — картинка прилетает вложением в следующем turno в той же сессии TUI. copy_vision.sh shot вызывает сам.
- **Long answers:** `colup ×40` scrolls ≈5000px to top; for answers longer than ~5 screens may not reach the true top — verify first frame shows answer start, increase count if needed.

## Резервный интернет-поиск (fallback)

Когда штатные инструменты не работают — `web_search`/`web_fetch` дают `Not authenticated` (нужен `ollama signin`), а `webq` тоже упёрся (нет сети к DDG, срезанный ответ) — Дипсик можно использовать как резервный источник актуальных фактов из интернета: он сам ищет/приводит свежие данные (погода, курсы, версии, новости).

- Спроси напрямую через `full_cycle.sh "<вопрос>"`, например «какая погода в <город> сегодня». Ответ: сначала копирование по зрению (`copy_vision.sh shot → click`), скриншот читать глазами только если клики не попали.
- Это дороже и медленнее, чем API-поиск: сначала попробуй лёгкие пути (webq, open-meteo/JSON-API), Дипсик — только если они не сработали.
- Формулируй вопрос самодостаточно: город/текущая дата/контекст — у него нет нашего диалога.

## Workflow for a new question

1. `full_cycle.sh "<question>"` — Chrome открывается, запрос пишется и отправляется, ответ приходит (заодно скролл + фото экрана с кнопкой Copy).
2. **ПРИОРИТЕТ: копированный текст.** `copy_vision.sh shot` → смотришь картинку → находишь Copy под последним ответом → `copy_vision.sh click X Y` → текст из `/tmp/deepseek_answer.md`.
3. Только если 2 клика не попали (буфер <50 B / мусор) — читаешь скитч `sessions/<ts>/full.png` глазами.
4. Отчёт пользователю строится по ТЕКСТУ, не по картинке.

## Предусловие перед запуском
- **Только консоль оркестратора активна.** Перед первым вызовом скилла убедиться, что в фокусе моя Konsole и других активных окон поверх нет: xdotool-цепочки и восстановление фокуса (`focus_consolidate.sh`) завязаны на том, что «домашним» окном является именно консоль оркестратора. Если активен другой app — сначала вернуть фокус в мою консоль и только тогда запускать full_cycle/copy_vision.

## Правило фокуса (обязательно)

После КАЖДОГО завершённого действия с DeepSeek/браузером вернуть фокус в Konsole оркестратора — так пользователь видит, что ПК снова можно использовать:
- `full_cycle.sh`, `copy_vision.sh` уже делают это сами (`../focus_consolidate.sh`).
- Любая ручная цепочка xdotool/spectacle/show_image или отдельный скрипт — после неё вызвать `/home/voron/Документы/VB-ollama/Скрипты_ИИ/focus_consolidate.sh`.
- Не оставлять Chrome «верхним» окном после отчёта пользователю.

## Заготовка (template) для других браузерных задач

Эти скрипты — заготовка/base для любого xdotool-автоматизма браузера, не только чата с Дипсиком:
- клик по закладкам, кнопкам и другим элементам страницы;
- работа с другими браузерными ИИ (GPT, Claude, Yandex и т.д.): подставь свой URL в `urls/*.txt`, настрой координаты кнопок/инпута в full_cycle.sh и WM_CLASS окна; чтение ответа — тот же vision-flow (`copy_vision.sh`);
- любая цепочка «активировать окно → кликнуть → ввести → дождаться → снять скриншот».

Что адаптировать под новую цель: `win_fix.sh` (размер/WM_CLASS окна), координаты в `full_cycle.sh`, условия стоп в `scroll_capture.sh`.
