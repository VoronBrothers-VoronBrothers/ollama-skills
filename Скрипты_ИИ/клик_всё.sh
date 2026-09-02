#!/bin/bash
# клик_всё.sh — спрятаться → клик мышью (X Y) → развернуться
# Использование: клик_всё.sh <X> <Y> [задержка_сек]
# Пример: клик_всё.sh 716 824
set -euo pipefail
S=$(cd "$(dirname "$0")" && pwd)

X="${1:?нужен X}"
Y="${2:?нужен Y}"
DELAY="${3:-0.5}"

id=$(xdotool search --name 'ollama$' 2>/dev/null | head -n1)
[ -n "$id" ] || { echo "окно не найдено"; exit 1; }
xdotool windowminimize "$id"

sleep 1
python3 "$S/click_xy.py" "$X" "$Y" "$DELAY"

sleep 1
xdotool windowactivate "$id" 2>/dev/null || true
echo "готово: клик ($X, $Y)"
