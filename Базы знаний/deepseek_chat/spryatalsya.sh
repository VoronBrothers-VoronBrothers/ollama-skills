#!/usr/bin/env bash
# spryatalsya.sh — «спрятаться»: найти окно оркестратора и свёрнуть
set -euo pipefail
id=$(xdotool search --name 'ollama$' 2>/dev/null | head -n1 || true)
[ -n "$id" ] || { echo "окно оркестратора не найдено" >&2; exit 1; }
xdotool windowminimize "$id"
echo "спрятался. окно свёрнуто: $id"
