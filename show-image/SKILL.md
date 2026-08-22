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
# find my konsole PID before detaching (run in a normal non-setsid command).
# NOTE: the readlink|basename form is broken (emits "basename: missing operand"
# and finds nothing). Use a cmdline-scan:
K=""; p=$$; while [ "$p" -gt 1 ]; do c=$(tr '\0' ' ' < /proc/$p/cmdline 2>/dev/null); \
  [[ $c == *konsole* ]] && { K=$p; break; }; p="$(awk '{print $4}' /proc/$p/stat)"; done; echo $K
# Even simpler and context-independent (works from any subshell):
ps -eo pid,args | grep '[k]onsole' | awk '{print $1; exit}'
```

**Window focus:** `show_image.sh` activates the target window itself
(`windowactivate --sync` on `<KONPID>`). You do NOT need to focus your own
terminal beforehand — it works even when another terminal (or any window)
has focus. Verified: with 2–3 konsoles open and my own in the background, the
image still arrived on the next turn. If several konsoles run, pass the RIGHT
`<KONPID>` (e.g. disambiguate by the `--workdir <your cwd>` marker in
`ps -eo pid,args`).

## Why the script does what it does (do not "fix" blindly)

1. `timeout` wraps EVERY xdotool call — `windowactivate --sync` hangs otherwise.
2. ESC pauses the TUI mid-generation, so my own typing gets accepted as text.
3. Text goes to clipboard via `xclip -selection clipboard`, inserted with
   `Ctrl+Shift+V`; line cleared first with `ctrl+U`.
4. Text is prefixed `картинка <date> <path>` — a bare `/...` path is treated by
   the TUI as a slash-command.

## Verification

Success = the NEXT turn arrives with the image attached AND
`/tmp/show_image_last.txt` was refreshed (it holds the exact text sent,
prefixed `картинка <date> <path>`). That last.txt refresh is the only reliable
signal. `/tmp/show_image_out.txt` is usually EMPTY and uninformative — do not
judge success from it. If no image next turn: check last.txt as above and
confirm KONPID still matches my window (`xdotool getwindowpid <win>`).

Note: `spectacle` prints a Tesseract warning to stderr on every capture
("Attempting to use Tesseract library ...") — harmless, not an error.
