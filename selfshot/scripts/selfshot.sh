#!/bin/bash
# Защита: выход при любой ошибке, неинициализированной переменной или сбое в пайпе
# Редактировать скрипт без команды ЗАПРЕЩЕНО
set -euo pipefail

S="orchestrator-this-is-your-own-tmux-send-pictures-here-with-task"

# Проверяем, существует ли целевая сессия tmux
if ! tmux has-session -t "$S" 2>/dev/null; then
    echo "Критическая ошибка: Сессия tmux '$S' не найдена!" >&2
    exit 1
fi

TASK="${1:-Посмотри на скриншот и ответь: что ты видишь? загораживают ли окна друг друга? напиши подробно}"

# Автоматический выбор скриншотера (если один упал или отсутствует)
filepath="/tmp/Screenshot_$(date +%Y%m%d_%H%M%S).png"

if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
    # Если есть графический сервер, делаем снимок экрана
    if command -v maim &>/dev/null; then
        maim -u "$filepath"
    elif command -v scrot &>/dev/null; then
        scrot -z "$filepath"
    elif command -v spectacle &>/dev/null; then
        spectacle -b -f -n -o "$filepath"
    else
        echo "Внимание: Графика есть, но утилиты скриншотов не найдены." >&2
    fi
else
    # Если графики нет (ИИ в консоли), снимаем текстовый дамп самого tmux!
    filepath="/tmp/Tmux_Dump_$(date +%Y%m%d_%H%M%S).txt"
    tmux capture-pane -e -J -t "$S" -p > "$filepath"
fi

MESSAGE=" [Сообщение из скрипта selfshot, 1. выполни задачу по изображению:] $TASK [2. далее переходи к основной задаче] $filepath "

# БРОНЕБОЙНАЯ ПЕРЕДАЧА: Загружаем текст в буфер памяти tmux (исключает искажение символов)
tmux set-buffer -b "space_task" "$MESSAGE"

# Очищаем строку ввода (Control + U) перед отправкой
tmux send-keys -t "$S" C-u
sleep 1

# Вставляем весь текст мгновенно и атомарно из буфера памяти
tmux paste-buffer -b "space_task" -t "$S"
sleep 1

# --- БЛОК ПАУЗЫ и ДУБЛИРОВАНИЯ ВВОДА (Каскадный прострел) ---
# Если интерфейс лагает, первый Enter может уйти в пустоту.
# Мы шлем серию разных сигналов отправки с микропаузами, чтобы "пробить" любой затуп.
tmux send-keys -t "$S" -K C-[     # 0-й пауза чата, перехват ввода
sleep 1
tmux send-keys -t "$S" -K C-m     # 1-й силовой ввод (нативный ASCII Carriage Return)
sleep 1
tmux send-keys -t "$S" Enter   # 2-й ввод (эмуляция клавиши терминала)
sleep 1
tmux send-keys -t "$S" -N 20 C-m
sleep 0.5
tmux send-keys -t "$S" -N 20 Enter
sleep 0.5
tmux send-keys -t "$S" -N 20 -K Enter
sleep 1
tmux send-keys -t "$S" DC
tmux send-keys -t "$S" C-m
tmux send-keys -t "$S" Enter
