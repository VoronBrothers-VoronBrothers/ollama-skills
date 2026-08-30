#!/usr/bin/env bash
# screenshot.sh — скриншот по скиллу "screenshot":
#   снимок + уникальное имя в /tmp + путь в буфер обмена + проверка PNG.
set -euo pipefail

FILE="/tmp/screenshot_$(date +%Y%m%d_%H%M%S)_$$${RANDOM}.png"
spectacle -b -f -n -o "$FILE" 2>/dev/null

# путь в CLIPBOARD (без -C у spectacle: он теряет ownership буфера)
printf '%s' "$FILE" | xclip -selection clipboard > /dev/null

# обязательная проверка: PNG, размер, пустота кадра
python3 - "$FILE" <<'PY'
import sys, struct, os
from PIL import Image
p = sys.argv[1]
with open(p, 'rb') as fh:
    head = fh.read(24)
assert head[:8] == b'\x89PNG\r\n\x1a\n', "not a PNG"
w, h = struct.unpack('>II', head[16:24])
im = Image.open(p).convert("RGB")
spread = max(mx - mn for mn, mx in im.getextrema())
print(f"PNG OK {w}x{h} {os.path.getsize(p)} bytes spread={spread} blank={spread < 12}")
if spread < 12:
    sys.exit("blank=True — кадр почти пустой, переснять")
PY

echo "saved + clipboard: $FILE"
