#!/usr/bin/env bash
# focus_consolidate.sh — поднимает окно Konsole (оркестратора) на передний план.
# Вызывай после работы с браузером/скриншотами, чтобы пользователь видел: "ИИ закончил".
set -u
export DISPLAY="${DISPLAY:-:0}"

WIN=""
for w in $(xdotool search --class konsole 2>/dev/null); do
  n=$(xdotool getwindowname "$w" 2>/dev/null)
  if [[ "$n" == *ollama* ]]; then WIN="$w"; break; fi
done
if [ -z "$WIN" ]; then
  # fallback: любое konsole с PID родителя ollama
  for w in $(xdotool search --class konsole 2>/dev/null); do
    n=$(xdotool getwindowname "$w" 2>/dev/null)
    [ -n "$n" ] && WIN="$w"
  done
fi
[ -z "$WIN" ] && { echo "focus_consolidate: konsole не найден"; exit 1; }

xdotool windowactivate --sync "$WIN" 2>/dev/null
xdotool windowraise "$WIN" 2>/dev/null
echo "focus_consolidate: Konsole ($WIN) на передний план"
