#!/usr/bin/env bash
# simple_screenshot.sh — скриншот: снимок + путь в буфер (без проверки python)
set -euo pipefail

FILE="/tmp/screenshot_$(date +%Y%m%d_%H%M%S)_$$${RANDOM}.png"
spectacle -b -f -n -o "$FILE" 2>/dev/null

printf '%s' "$FILE" | xclip -selection clipboard > /dev/null

echo "saved + clipboard: $FILE"
