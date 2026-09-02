#!/usr/bin/env bash
# win_close.sh ID [задержка_сек=10] — закрыть окно по ТОЧНОМУ X11-ID (число) через задержку
# ID обязательно и должен быть числом: xdotool search / win_id.sh даёт номера.
# Таймер изолирован (setsid), чтобы пережил смерть собственного терминала.
set -euo pipefail
id="${1:-}"
[[ "$id" =~ ^[0-9]+$ ]] || { echo "нужен точный ID окна: win_close.sh <ID> [задержка_сек]" >&2; exit 1; }
delay="${2:-10}"
echo "окно $id будет закрыто через ${delay}с"
setsid bash -c "sleep '$delay'; xdotool windowkill '$id'" </dev/null >/dev/null 2>&1 &
echo "таймер запущен (pid $(jobs -p | tail -n1))"
