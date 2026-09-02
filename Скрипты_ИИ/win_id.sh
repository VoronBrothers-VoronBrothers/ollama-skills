#!/usr/bin/env bash
# win_id.sh — вернуть X11-идентификатор окна оркестратора (консоль с ollama TUI)
set -euo pipefail
id=$(xdotool search --name 'ollama$' 2>/dev/null | head -n1 || true)
[ -n "$id" ] || { echo "окно ollama не найдено" >&2; exit 1; }
echo "$id"
