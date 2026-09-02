#!/usr/bin/env bash
# win_restore.sh ID — развернуть (разминимизировать) окно по ТОЧНОМУ X11-ID (число, из win_id.sh)
set -euo pipefail
id="${1:-}"
[[ "$id" =~ ^[0-9]+$ ]] || { echo "нужен точный ID окна: win_restore.sh <ID>" >&2; exit 1; }
xdotool windowmap "$id" windowactivate "$id"
echo "развёрнуто: $id"
