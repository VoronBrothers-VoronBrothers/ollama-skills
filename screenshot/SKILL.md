---
name: screenshot
description: Capture a screenshot of the desktop or a window and verify it. Use when the user asks for a screenshot, screen capture, "what's on screen", or needs to inspect a GUI, window, or the result of a command visually.
---

# Screenshot

Capture the screen with `spectacle` (KDE) in **background mode**, then verify the file is a real, non-blank image. Never use GUI mode — it opens an interactive window and hangs the shell.

## Capture

Always use a **unique filename** (timestamp + PID). Several agents may run at once and a fixed path like `/tmp/screen.png` will get clobbered.

```bash
shot="/tmp/screen_$(date +%s)_$$.png"
spectacle -b -f -n -o "$shot"
echo "saved: $shot"
```

- `-b` background mode (required — capture and exit, no GUI).
- `-f` full screen (default). Other targets: `-a` active window, `-u` window under cursor, `-r` region.
- `-n` no notification popup.
- `-o <file>` save to file (only valid in background mode).
- Optional: `-p` include the cursor, `-d <ms>` delay before capture.

## Verify (mandatory)

Do not assume the file is good. Confirm it exists, is a valid PNG, and is not a blank/black frame.

```bash
python3 - "$shot" <<'PY'
import sys, struct, os
from PIL import Image
p=sys.argv[1]
with open(p,'rb') as fh: head=fh.read(24)
assert head[:8]==b'\x89PNG\r\n\x1a\n', "not a PNG"
w,h=struct.unpack('>II', head[16:24])
im=Image.open(p).convert("RGB")
spread=max(mx-mn for mn,mx in im.getextrema())   # 0..255; low => near-uniform/blank
blank = spread < 12
print(f"PNG OK {w}x{h} {os.path.getsize(p)} bytes  spread={spread} blank={blank}")
PY
```

A real UI has wide color spread (well above ~12). If `blank=True` or the file is missing, re-capture before reporting success.

## Look at it

The image file does not enter the context by itself. To actually read it:

- **Prefer the orchestrator's own vision** (qwen3.8-orchestrator): attach the file to the message, or send it via the API in the `images` field (base64) to `POST /api/generate`.
- Or send it to a dedicated vision model the same way.

Use it to read on-screen text, describe windows/controls, or cross-check the result of a command.

## Send to a vision model (slow — plan for it)

Sending a screenshot to a vision model is the slow part: a **cold model load** (an 18 GB model can take well over 150 s) plus generation. Two levers cut the time a lot (both verified).

**1. Downscale first.** 1920x1080 → 1280x720 stays fully readable for UI text and cuts ~56% of vision tokens:

```bash
small="/tmp/screen_small_$(date +%s)_$$.png"
python3 - "$shot" "$small" <<'PY'
import sys
from PIL import Image
src, dst = sys.argv[1], sys.argv[2]
im = Image.open(src).convert("RGB")
w, h = im.size
scale = min(1.0, 1280 / max(w, h))
if scale < 1.0:
    im = im.resize((int(w*scale), int(h*scale)), Image.LANCZOS)
im.save(dst, optimize=True)
print(f"downscaled {w}x{h} -> {im.size[0]}x{im.size[1]}")
PY
```

Send `$small` (base64) in the `images` field, not the full-res `$shot`. Keep the longest side ≥1280px so on-screen text stays legible.

**2. Ask for a concise, targeted answer.** "Read these 3 items verbatim" finished in ~40 s (warm model); "describe everything in detail" ran past 150 s. Name exactly what you need instead of a full description.

**Call protocol:** cold load + generation easily exceeds the ~180 s bash limit, so run vision calls in **background + polling** (see the `ollama-safe-call` skill). The first call after a model unload is the slowest — expect it to time out in foreground and retry in background; that is normal, not a model error.

## Pitfalls

- `-g` (GUI) is the default and will hang — always pass `-b`.
- A `file`/`ls` check that fails is often a false negative (missing `file` binary, or a race right after capture); trust the PNG-header + variance check above.
- Keep the filename unique per call; do not reuse a constant path.
