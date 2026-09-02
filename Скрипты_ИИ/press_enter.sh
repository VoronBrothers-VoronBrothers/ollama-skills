#!/bin/bash
# Симуляция нажатия Enter (в активное окно)
# Использование: ./press_enter.sh [окно]
#   без аргументов — в текущее активное окно
#   с аргументом    — принудительно в указанное окно (PID окна или WM-класс), напр.: ./press_enter.sh firefox

if [ -n "$1" ]; then
  # фокусируемся на нужном окне по PID (xdotool search --pid)
  WIN=$(xdotool search --pid "$1" | head -1)
  if [ -n "$WIN" ]; then
    xdotool windowactivate "$WIN" 2>/dev/null
  fi
fi

sleep 1  # задержка 1 секунда перед нажатием
xdotool key Return && echo "Enter отправлен ✅" || echo "Ошибка: не удалось отправить Enter"
sleep 1  # задержка 1 секунда после нажатия
