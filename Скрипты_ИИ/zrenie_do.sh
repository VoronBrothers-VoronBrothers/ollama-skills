#!/usr/bin/env bash
# zrenie_do.sh — полный цикл: скрин → TUI (ollama+Enter) → JSON координаты → клик (+ввод текста)
# Точные координаты модель даёт только через TUI-запуск: "ollama" → Enter, картинка полным путём в сообщении.
# Использование:
#   zrenie_do.sh "найди кнопку X и верни её координаты"          — найти и кликнуть
#   zrenie_do.sh "найди поле поиска" "текст для ввода"           — клик + ввести текст
#   zrenie_do.sh --show "задача"                                  — только показать координаты, не кликать
set -euo pipefail
S=$(cd "$(dirname "$0")" && pwd)
export DISPLAY="${DISPLAY:-:0}"
SESSION="zrenie_fresh"

SHOW=0
[ "${1:-}" = "--show" ] && { SHOW=1; shift; }
[ $# -lt 1 ] && { echo "Использование: zrenie_do.sh [--show] \"задача\" [текст_ввода]"; exit 1; }
TASK="$1"; TEXT="${2:-}"

# --- 1. Скриншот (своё окно свёрнуто) ---
W=$(xdotool search --name '~ : ollama' | head -n1 || true)
[ -n "$W" ] && { xdotool windowminimize "$W"; sleep 0.8; }
FILE="/tmp/zrenie/do_$(date +%H%M%S).png"
spectacle -b -f -n -o "$FILE" >/dev/null 2>&1 || { [ -n "$W" ] && xdotool windowactivate "$W" || true; echo "ошибка: скриншот не получен"; exit 1; }
[ -n "$W" ] && xdotool windowactivate "$W" 2>/dev/null || true

# --- 2. TUI-сессия: ollama → Enter (первый пункт) ---
pane_is_tui() { tmux capture-pane -t "$SESSION" -p 2>/dev/null | grep -q "full access enabled"; }
if ! tmux has-session -t "$SESSION" 2>/dev/null || ! pane_is_tui; then
    tmux kill-session -t "$SESSION" 2>/dev/null || true
    tmux new-session -d -s "$SESSION"
    sleep 1.5
    tmux send-keys -t "$SESSION" "ollama" Enter
    sleep 4
    tmux send-keys -t "$SESSION" Enter
    sleep 4
fi
pane_is_tui || { echo "ошибка: TUI не поднялся"; exit 1; }

# --- 3. Задача + полный путь к картинке в одном сообщении ---
MSG="$FILE найди на изображении: $TASK. Ответь одной строкой строго JSON {\"x\": <целое>, \"y\": <целое>} — координаты центра объекта, от левого верхнего угла экрана. Без пояснений и мыслей."
tmux send-keys -t "$SESSION" -l -- "$MSG"
tmux send-keys -t "$SESSION" Enter

# --- 4. Ждём JSON в ответе (до 90 сек) ---
COORDS=""
for i in $(seq 1 60); do
    sleep 3
    LINE=$(tmux capture-pane -t "$SESSION" -p -S -80 | grep -oE '\{[ "]*x[" ]*[:=] *[-0-9]+[ ,]*[" ]*y[" ]*[:=] *[-0-9]+[^}]*\}' | tail -n1 || true)
    [ -n "$LINE" ] && { COORDS="$LINE"; break; }
done
[ -z "$COORDS" ] && { echo "ошибка: JSON не получен. Последний вывод TUI:"; tmux capture-pane -t "$SESSION" -p -S -15 | sed '/^$/d' | tail -8; exit 1; }

X=$(echo "$COORDS" | grep -oE '[0-9]+' | head -n1)
Y=$(echo "$COORDS" | grep -oE '[0-9]+' | tail -n1)
echo "координаты: ($X, $Y)"

# --- 5. Действие: клик (+ввод) ---
if [ "$SHOW" = 1 ]; then
    echo "--show: клик пропущен"
else
    python3 "$S/click_xy.py" "$X" "$Y" 0.4
    if [ -n "$TEXT" ]; then
        sleep 0.5
        xdotool type --clearmodifiers --delay 80 "$TEXT"
        echo "введено: $TEXT"
    fi
fi
