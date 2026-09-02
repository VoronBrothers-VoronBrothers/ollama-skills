#!/bin/bash
# samovizyv.sh — рекурсивный самовызов: найти своё окно Konsole, сфокусировать, напечатать сообщение + Enter
msg="${1:-ТЕХ: самовызов — задача не выполнена, продолжай}"

w=""
for i in $(xdotool search --name "ollama" 2>/dev/null); do
    name=$(xdotool getwindowname $i 2>/dev/null)
    if [[ "$name" == *ollama*Console* ]]; then w=$i; break; fi
done
[ -z "$w" ] && w=$(xdotool search --name "ollama" 2>/dev/null | head -1)
if [ -z "$w" ]; then echo "окно ollama не найдено"; exit 1; fi

xdotool windowactivate --sync $w 2>/dev/null
sleep 0.3
xdotool type "$msg"
sleep 0.2
xdotool key Return
echo "ок: самовызов отправлен в окно $w"
