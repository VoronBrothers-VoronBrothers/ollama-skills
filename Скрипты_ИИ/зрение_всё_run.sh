#!/bin/bash
# зрение_всё_run.sh — зрение конвейер (клон зрение_всё.sh): скрин → путь в буфер → проверка → ollama run <модель> в tmux → задача + путь
# Использование:
#   зрение_всё_run.sh                     — задача по умолчанию, модель по умолчанию
#   зрение_всё_run.sh "задача"            — своя задача
#   зрение_всё_run.sh "задача" "модель"   — своя модель (по умолчанию orchestrator:latest)
set -uo pipefail
export DISPLAY="${DISPLAY:-:0}"

SESSION="zrenie_run"                                  # имя tmux-сессии
MODEL="${2:-orchestrator:latest}"                   # модель через ollama run, можно свою
TASK="${1:-скрипт зрения отработал, вот изображение сделанное с помощью скрипта}"   # своя задача — первым аргументом

# 1. Сворачиваю себя → скриншот → разворачиваю
W=$(xdotool search --name '~ : ollama' 2>/dev/null | head -n1 || true)
[ -n "$W" ] && { xdotool windowminimize "$W"; sleep 1; }
FILE="/tmp/screenshot_$(date +%Y%m%d_%H%M%S)_$$${RANDOM}.png"
spectacle -b -f -n -o "$FILE" >/dev/null 2>&1 || { echo "ошибка: скриншот не получен"; exit 1; }
[ -n "$W" ] && xdotool windowactivate "$W" 2>/dev/null || true

# 2. Путь в буфер (clipboard) + сразу читаем обратно из той же трубы
printf '%s' "$FILE" | xclip -selection clipboard > /dev/null 2>&1 &
XC="$!"
TEXT=""
for i in 1 2 3; do
    TEXT="$(xclip -selection clipboard -o)"
    [ "$TEXT" = "$FILE" ] && break
    sleep 0.3
done

# 3. Проверка буфера: путь должен совпасть и файл существовать
if [ "$TEXT" != "$FILE" ] || [ ! -f "$TEXT" ]; then
    echo "ошибка: буфер не совпал или файла нет: '$TEXT'" >&2
    exit 1
fi

# 4. Запускаю ollama run <модель> в tmux (если сессии ещё нет) — REPL живёт в окне, контекст привязан к сессии
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    tmux new-session -d -s "$SESSION"
    sleep 1.5                       # пауза: клавиши не должны улететь раньше программы
    tmux send-keys -t "$SESSION" "ollama run $MODEL" Enter
    sleep 3                         # пауза на запуск (первый запрос после загрузки модели дольше)
fi

# 5. Задача + путь картинки в одном сообщении
MSG="задача: ${TASK} | скриншот: $FILE"
tmux send-keys -t "$SESSION" -l -- "$MSG"
sleep 0.3
tmux send-keys -t "$SESSION" Enter

echo "готово: $MSG (сессия $SESSION, модель $MODEL)"
