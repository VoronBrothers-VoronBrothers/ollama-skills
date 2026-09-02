#!/bin/bash
# Очередь сообщений себе в чат: /tmp/selfqueue.txt (строка = сообщение)
# Печатает напрямую xdotool type — буфер не нужен
export DISPLAY=:0
Q=/tmp/selfqueue.txt
[ -n "$1" ] && Q=$1
LOG=/tmp/ochered.log

echo "=== Запуск $(date) ===" > $LOG
W=$(xdotool search --onlyvisible "" | while read w; do n=$(xdotool getwindowname "$w" 2>/dev/null); case "$n" in *Konsole*) echo "$w"; exit;; esac; done)
echo "Окно: $W" >> $LOG

i=0
while IFS= read -r msg || [ -n "$msg" ]; do
  i=$((i+1))
  [ -z "$msg" ] && continue
  xdotool windowactivate "$W"
  sleep 0.5
  xdotool type --clearmodifiers "$msg" >> $LOG 2>&1
  sleep 5
  xdotool key --window "$W" --clearmodifiers Return
  echo "[$i] Отправлено $(date)" >> $LOG
done < "$Q"
echo "=== Готово $(date) ===" >> $LOG
