#!/bin/bash
# Симуляция нажатия Esc (в активное окно)
# Использование: ./press_esc.sh [окно]
#   без аргументов — в текущее активное окно
#   с аргументом    — принудительно в указанное окно (PID окна), напр.: ./press_esc.sh <PID>

if [ -n "$1" ]; then
  WIN=$(xdotool search --pid "$1" | head -1)
  if [ -n "$WIN" ]; then
    xdotool windowactivate "$WIN" 2>/dev/null
  fi
fi
xdotool key Escape && echo "Esc отправлен ✅" || echo "Ошибка: не удалось отправить Esc"
