#!/bin/bash
# Симуляция нажатия Shift+Insert (вставка) в активное окно
# Использование: ./press_ins.sh [окно]
#   без аргументов — в текущее активное окно
#   с аргументом    — принудительно в указанное окно (X11 ID окна)

if [ -n "$1" ]; then
  xdotool windowactivate "$1" 2>/dev/null
fi


xdotool key --clearmodifiers shift+Insert && echo "Shift+Insert отправлен ✅" || echo "Ошибка: не удалось отправить Shift+Insert"

