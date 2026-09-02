#!/bin/bash
# Симуляция нажатия Ctrl+V (вставка) в активное окно
# Использование: ./press_paste.sh [окно]
#   без аргументов — в текущее активное окно
#   с аргументом    — принудительно в указанное окно (X11 ID окна), напр.: ./press_paste.sh 85983243

if [ -n "$1" ]; then
  xdotool windowactivate "$1" 2>/dev/null
fi

sleep 1  # задержка 1 секунда перед нажатием
xdotool key --clearmodifiers ctrl+v && echo "Ctrl+V отправлен ✅" || echo "Ошибка: не удалось отправить Ctrl+V"
sleep 1  # задержка 1 секунда после нажатия
