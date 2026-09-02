#!/bin/bash
# вызов_ии_в_tmux.sh — открывает ollama в tmux-сессии и запускает модель
# Использование: вызов_ии_в_tmux.sh [модель] [имя_сессии]
#   по умолчанию: модель orchestrator, сессия third_hand
set -uo pipefail

MODEL="${1:-orchestrator}"      # вместо "orchestrator" можно ввести другое название модели
SESSION="${2:-third_hand}"      # имя tmux-сессии (по умолчанию third_hand)

# Если сессии нет — создаём и запускаем ollama; если есть — просто идём дальше
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    tmux new-session -d -s "$SESSION"
    sleep 1.5

    # 1. Печатаем ollama → Enter
    tmux send-keys -t "$SESSION" "ollama" Enter
    sleep 3

    # 2. Стрелка вправо → печатаем модель → Enter
    tmux send-keys -t "$SESSION" Right
    sleep 0.5
    tmux send-keys -t "$SESSION" -l -- "$MODEL"
    sleep 1
    tmux send-keys -t "$SESSION" Enter

    # Проверка по футеру убрана: сообщения всё равно встают в очередь
    sleep 3
fi

echo "готово: tmux-сессия $SESSION запущена, модель: $MODEL"
