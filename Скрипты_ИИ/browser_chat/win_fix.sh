#!/usr/bin/env bash
# win_fix.sh [W=1920] [H=1024] — выравнивает ОСНОВНОЕ окно google-chrome в 0,0 + размер.
# Точный WM_CLASS = "google-chrome" (не -stable: это Prizrak-box/VPN).
set -euo pipefail
W=${1:-1920}; H=${2:-1024}
WIN=""
while read -r w; do
  cls=$({ xprop -id "$w" WM_CLASS 2>/dev/null || true; } | sed 's/WM_CLASS(STRING) = //' | cut -d, -f1 | tr -d '"')
  [ "$cls" = "google-chrome" ] && WIN=$w
done < <(xdotool search --name "")
[ -z "$WIN" ] && { echo "браузер google-chrome не найден"; exit 1; }
xdotool windowactivate --sync "$WIN" windowmove "$WIN" 0 0 windowsize "$WIN" "$W" "$H"
sleep 0.8
echo "ok: окно $WIN в 0,0 ${W}x${H}"
