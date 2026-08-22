---
name: show-image
description: Send an image path to the orchestrator's own terminal (its konsole) so the next turn arrives with the screenshot attached — no new terminal. Use when you need to "see" a screenshot / the desktop / a GUI and feed it back to yourself in this same TUI session.
---

# Show an image to myself (orchestrator TUI)

Feed a screenshot into my own terminal window so the NEXT turn arrives with the
image attached. Everything runs in my current konsole — no new terminal opened.

## One-shot usage

```bash
cd /home/voron/Документы/VB-ollama/Скрипты_ИИ
IMG=/tmp/self_$$.png
spectacle -b -f -n -o "$IMG"          # full-desktop screenshot (skip if image already exists)
setsid ./show_image.sh "$IMG" <KONPID> </dev/null >/tmp/show_image_out.txt 2>&1 &
```

`<KONPID>` = PID of my konsole. When NOT detached you can omit it — the script
walks its own PID chain (bash→ollama→zsh→konsole) to find the window. But when
launched via `setsid`, the process is re-parented to init and that chain breaks,
so pass KONPID explicitly:

```bash
# find my konsole PID before detaching (run in a normal non-setsid command):
K=""; p=$$; while [ "$p" -gt 1 ]; do e="$(readlink /proc/$p/exe|basename)"; \
  [ "$e" = konsole ] && { K=$p; break; }; p="$(awk '{print $4}' /proc/$p/stat)"; done; echo $K
```

## Why the script does what it does (do not "fix" blindly)

1. `timeout` wraps EVERY xdotool call — `windowactivate --sync` hangs otherwise.
2. ESC pauses the TUI mid-generation, so my own typing gets accepted as text.
3. Text goes to clipboard via `xclip -selection clipboard`, inserted with
   `Ctrl+Shift+V`; line cleared first with `ctrl+U`.
4. Text is prefixed `картинка <date> <path>` — a bare `/...` path is treated by
   the TUI as a slash-command.

## Verification

Next turn should arrive WITH the image attached. If it doesn't: check
`/tmp/show_image_out.txt` and `/tmp/show_image_last.txt` (the exact text sent),
and confirm KONPID still matches my window (`xdotool getwindowpid <win>`).
