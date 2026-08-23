---
name: browser-chat
description: Browser chat automation for DeepSeek (Дипсик / chat.deepseek.com) via scripts — open a URL from file, deterministically sized Chrome, type and submit a question, capture short or long (scrollable) answers as stitched screenshots. Use when the user asks to ask something to Дипсик/DeepSeek («задай вопрос дипсику»), ask in a web chat/browser, automate a browser session, or capture a long answer.
---

# Browser chat automation

All scripts live in `/home/voron/Документы/VB-ollama/Скрипты_ИИ/browser_chat/`. Scripts are tested and working; prefer running them over re-inventing with xdotool.

## Full cycle (main entry point)

```bash
cd /home/voron/Документы/VB-ollama/Скрипты_ИИ/browser_chat
./full_cycle.sh "<question>" [WAIT_SECONDS=12]
```

Does: auto-start Chrome if not running (`setsid google-chrome https://chat.deepseek.com/`, polls ≤20 s) → New chat → activate window → click input → clear (`ctrl+a Delete`) → type → Enter → wait → scroll_capture → saves to `sessions/<timestamp>/` (question.txt, full.png/answer.png, meta.json, frames).

## Individual scripts

| Script | Purpose |
|---|---|
| `win_fix.sh [W=1920] [H=1024]` | Move/resize the chat Chrome window to 0,0 W×H. Matches EXACT WM_CLASS `google-chrome`. |
| `open_url.sh <file-or-url>` | Open URL (or file in `urls/*.txt` containing one) in existing browser. |
| `scroll_capture.sh <session-dir>` | Multi-frame scroll capture → stitched `full.png` + `frame_NNN.png`. Stops on md5 frame repeat or 30-frame cap. |
| `copy_answer.sh [X=723] [Y=auto] [out=/tmp/deepseek_answer.md]` | Click copy-icon of last answer → clipboard → markdown file. Y=auto (default) runs detect_copy_row.py; clears clipboard BEFORE the click so stale content is impossible. Fails if buffer <50 bytes or looks like a file path. |
| `detect_copy_row.py` | Spectacle -b -f fullscreen shot → scan column x=715–735, y=400–940 in grayscale for bright (>150) runs (dark theme) → prints center Y of the last icon row (or FAIL). Needs PIL + spectacle; no numpy. |
| `save_session.sh <question> <screenshot>` | Save question + image + meta.json into a session dir (utility). |

## Key facts (learned, do not re-derive)

- **Two Chrome instances exist.** The chat browser is WM_CLASS exactly `google-chrome`; Prizrak-box VPN is `google-chrome-stable`. Never match by substring.
- **Focus before every input:** `xdotool windowactivate --sync $WIN` must precede each keystroke sequence or input lands in Konsole (PID 1316128).
- **Input coordinates** (window at 0,0, 1920×1024): New chat button ≈ (93,213); input field ≈ (960,570). Scroll cursor must be at (960,400) so wheel targets content area.
- **Copy-icon row** (per answer, just below its text): copy ≈ (723, Y); refresh/like/dislike/share follow at +42/+77/+110/+142 px. Y varies with answer length and scroll — detect_copy_row.py finds it automatically; fall back to a manual Y only if detection fails.
- **Clipboard hygiene:** clear with `printf '' | xclip -selection clipboard` before every copy click — otherwise stale content (old answers, file paths) silently passes as "the answer".
- **Chrome runs WITHOUT `--remote-debugging-port`** — CDP not available; text extraction is vision/screenshot only.
- **Screenshots:** `spectacle -b -f -n -o $shot`, then crop content region x=480–1440, y=100–980 for stable comparison.
- **Self-vision loop to see a screenshot in this same TUI session:**
  `setsid /home/voron/Документы/VB-ollama/Скрипты_ИИ/show_image.sh <img> 1316128 </dev/null >/tmp/show_image_out.txt 2>&1 &` — the image arrives as an attachment next turn.
- **Long answers:** `colup ×40` scrolls ≈5000px to top; for answers longer than ~5 screens may not reach the true top — verify first frame shows answer start, increase count if needed.

## Workflow for a new question

1. Run `full_cycle.sh "<question>"` (it handles everything including scroll capture).
2. Show result via show_image.sh and/or read meta.json + view full.png.
3. Report: session dir path, image size, answer text if readable from screenshot.

## Правило фокуса (обязательно)

После КАЖДОГО завершённого действия с DeepSeek/браузером вернуть фокус в Konsole оркестратора — так пользователь видит, что ПК снова можно использовать:
- `full_cycle.sh` и `copy_answer.sh` уже делают это сами (`../focus_consolidate.sh`).
- Любая ручная цепочка xdotool/spectacle/show_image или отдельный скрипт (detect_copy_row.py и пр.) — после неё вызвать `/home/voron/Документы/VB-ollama/Скрипты_ИИ/focus_consolidate.sh`.
- Не оставлять Chrome «верхним» окном после отчёта пользователю.

## Заготовка (template) для других браузерных задач

Эти скрипты — заготовка/base для любого xdotool-автоматизма браузера, не только чата с Дипсиком:
- клик по закладкам, кнопкам и другим элементам страницы;
- работа с другими браузерными ИИ (GPT, Claude, Yandex и т.д.): подставь свой URL в `urls/*.txt`, настрой координаты кнопок/инпута и WM_CLASS окна;
- любая цепочка «активировать окно → кликнуть → ввести → дождаться → снять скриншот».

Что адаптировать под новую цель: `win_fix.sh` (размер/WM_CLASS окна), координаты в `full_cycle.sh`, условия стоп в `scroll_capture.sh`.
