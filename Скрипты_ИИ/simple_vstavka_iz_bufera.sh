#!/usr/bin/env bash
# simple_vstavka_iz_bufera.sh — просто вставить из буфера + Enter (отправить)
# Запуск: nohup bash simple_vstavka_iz_bufera.sh > /tmp/sv.log 2>&1 &
set -euo pipefail
S=$(cd "$(dirname "$0")" && pwd)

"$S/press_esc.sh" > /dev/null 2>&1
sleep 1
"$S/press_ins.sh"
sleep 15 #дожидаемся когда ии закончит сообщение
"$S/press_enter_vvod.sh"
sleep 5 #на всякий случай ещё ждём
"$S/press_enter_vvod.sh"
