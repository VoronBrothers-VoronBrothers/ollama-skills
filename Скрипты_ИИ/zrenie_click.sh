#!/usr/bin/env bash
# zrenie_click.sh — зрение в фоне + клик по координатам в переднем плане
# Использование: zrenie_click.sh <X> <Y> [задержка]
set -euo pipefail
S=$(cd "$(dirname "$0")" && pwd)
if [[ $# -lt 2 ]]; then echo "Использование: zrenie_click.sh <X> <Y> [задержка]"; exit 1; fi
X=$1; Y=$2; DELAY=${3:-0.5}

"$S/bg-run.sh" "$S/зрение.sh"
echo "зрение в фоне, жду 12 сек..."
sleep 12
echo "клик по ($X, $Y):"
python3 "$S/click_xy.py" "$X" "$Y" "$DELAY"
