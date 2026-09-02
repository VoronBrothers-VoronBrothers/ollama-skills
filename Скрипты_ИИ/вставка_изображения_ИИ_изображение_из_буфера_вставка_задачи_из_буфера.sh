#!/usr/bin/env bash
# Запуск: в фоне, напр. `nohup bash pipeline_tail.sh > /tmp/pipeline_tail.log 2>&1 &`
set -euo pipefail
S=$(cd "$(dirname "$0")" && pwd)

"$S/press_ins.sh"
sleep 0.5
"$S/задача_в_буфер.sh"
sleep 0.5
"$S/press_ins.sh"
"$S/press_esc.sh"
sleep 2   # задержка после эскейпа
"$S/press_enter_vvod.sh"
