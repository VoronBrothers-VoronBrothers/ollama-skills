#!/usr/bin/env bash
# win_min.sh ID — свернуть окно по ТОЧНОМУ X11-ID (число, из win_id.sh)
set -euo pipefail
id="${1:-}"
[[ "$id" =~ ^[0-9]+$ ]] || { echo "нужен точный ID окна: win_min.sh <ID>" >&2; exit 1; }
xdotool windowminimize "$id"
echo "свернуто: $id"
