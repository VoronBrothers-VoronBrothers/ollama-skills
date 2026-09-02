#!/bin/bash
# зрение_всё.sh — зрение конвейер: скрин → путь в буфер → проверка буфера → я в tmux → задача + путь в одном сообщении
# Использование:
#   зрение_всё.sh            — задача по умолчанию
#   зрение_всё.sh "задача"    — своя задача (идёт вместе с путём в том же сообщении)
set -uo pipefail
export DISPLAY="${DISPLAY:-:0}"

SESSION="zrenie"          # имя tmux-сессии: команда `ollama`, меню → первый пункт
TASK="${*:-скрипт зрения отработал, картинка отправилась}"

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

# 4. Запускаю себя в tmux (если ещё не запущен) — через вызов_ии_в_tmux.sh
bash "$(dirname "$0")/вызов_ии_в_tmux.sh" orchestrator "$SESSION"

# 5. Задача + путь картинки в одном сообщении
MSG="задача: ${TASK} | скриншот: $FILE"
tmux send-keys -t "$SESSION" -l -- "$MSG"
sleep 0.3
tmux send-keys -t "$SESSION" Enter

echo "готово: $MSG"
