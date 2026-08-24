---
name: gui-input
description: Control the mouse and keyboard (move, click, type, press keys) to operate GUI apps. Use when the user asks to move the cursor, click a button, type text, press a key, or automate a desktop application.
---

# GUI input (mouse + keyboard)

Drive the X11 desktop with `xdotool`. Requires an X11 session (`XDG_SESSION_TYPE=x11`, `DISPLAY` set); on Wayland `xdotool` will not work.

## Safety (read first)

- `type`, `key`, `click` act on the **currently focused window** unless you pass `--window <id>`. Confirm the target before typing/clicking into a real app — it is not reversible.
- Prefer `--window <id>` for anything destructive. Find the right id with `focus.sh` (see Window targeting), not with `search --name`.
- Move the mouse back after a demo/test if you changed it.

## Mouse

```bash
xdotool getmouselocation --shell                 # current X/Y
xdotool mousemove 100 200                        # absolute position
xdotool mousemove_relative 40 0                  # relative move
xdotool mousemove_relative -- -40 0              # NEGATIVE numbers need the leading --
xdotool click 1                                  # 1=left 2=middle 3=right 4=wheel-up 5=wheel-down
xdotool mousedown 1 ; xdotool mouseup 1          # manual press/release
```

## Keyboard

```bash
xdotool type "hello world"                       # type text (into focused window)
xdotool type --delay 20 "slow text"             # ms between keystrokes
xdotool key Return                               # single key
xdotool key ctrl+c                               # modifier + key
xdotool key --window <id> alt+f4                # send to a specific window
```

Key names: letters, `Return`, `Tab`, `space`, `Escape`, `Up/Down/Left/Right`, `Shift_L`, `Control_L`, etc. Chained sequences use `+`.

## Window targeting

**Do NOT find windows with `xdotool search --name`** — it returns ghost/auxiliary windows ("Qt Selection Owner", compositing helpers) with 1x1/3x3 geometry. Activating one of them leaves focus on your own terminal, and `windowactivate --sync` can hang ~20s before clicks land in the wrong window.

Use the helper instead — it finds the real window by PID (largest geometry), activates with timeout, and VERIFIES focus (retries once):

```bash
/home/voron/Документы/VB-ollama/Скрипты_ИИ/focus.sh <process> [win-name-filter]
# e.g. focus.sh kcalc KCalc  -> prints the verified window id, exit 0 = safe to click
```

Typical flow: `focus.sh` → `mousemove`/`click`/`type`. Only if focus.sh is unavailable: `xdotool search --all --pid $(pgrep -f <app>)`, filter out windows <100x100, then `windowactivate`.

## Pitfalls

- Negative coordinates in `mousemove_relative` MUST be preceded by `--`, otherwise xdotool reads them as flags and fails.
- `type`/`key`/`click` go to the focused window by default — verify focus or pass `--window`.
- `windowactivate --sync` on a ghost/wrong window hangs ~20s before failing — always wrap in `timeout 5`.
- This is X11-only; check `XDG_SESSION_TYPE` before relying on it.
