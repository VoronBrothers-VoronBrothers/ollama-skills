#!/usr/bin/env bash
# ку_ку.sh — «покажись» (прятки): найти окно оркестратора и вывести на передний план + фокус
set -euo pipefail
# точное имя: '~ : ollama' — иначе ловит и Dolphin (напр. "GitHub ollama")
id=$(xdotool search --name '~ : ollama' 2>/dev/null | head -n1 || true)
[ -n "$id" ] || { echo "окно оркестратора не найдено" >&2; exit 1; }
# windowactivate: снимает свёртку (KWin unmiminize) + поднимает + фокус в одном флаге.
# windowfocus/raise ДО activate давали X Error BadMatch (X_SetInputFocus на unmapped окно).
xdotool windowactivate "$id" 2>/dev/null || true
echo "ку-ку! окно поднято: $id"
