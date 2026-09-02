#!/bin/bash
# Навечно: раз в 60с проверяем tmux-сессию оркестратора
export LC_ALL=C.UTF-8
S="orchestrator-this-is-your-own-tmux-send-pictures-here-with-task"
LAST_SHA=""
COOLDOWN=0
log() { echo "$(date '+%H:%M:%S') $*" >> /tmp/tmux_watch.log; }

log "=== watcher запущен (pid $$) ==="

while true; do
  SCREEN=$(tmux capture-pane -t "$S" -p 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | col -b)
  [ -z "$SCREEN" ] && { log "capture пуст (сессия мертва?)"; sleep 60; continue; }

  # 1. Откроем поле ввода: строки в рамке │...│, убрать рамку, курсор █ и пробелы
  INPUT=$(echo "$SCREEN" | grep '^│.*│$' | sed 's/^│//; s/│$//' | sed 's/█//g' | tr -d '[:space:]')

  if [ -n "$INPUT" ]; then
    # есть неотправленное сообщение — отправляем
    tmux send-keys -t "$S" Enter
    LAST_SHA=""
    COOLDOWN=1
    log "ОТПРАВЛЕНО неотправленное: $INPUT"
  else
    SHA=$(echo "$SCREEN" | md5sum | cut -d' ' -f1)
    if [ -n "$LAST_SHA" ] && [ "$SHA" = "$LAST_SHA" ] && [ "$COOLDOWN" -eq 0 ]; then
      # экран не менялся 60 секунд — ИИ остановился
      tmux send-keys -t "$S" -l -- "[это сообщение прислал автоматический скрипт tmux_watch.sh] продолжай задачу"
      tmux send-keys -t "$S" Enter
      LAST_SHA=""
      COOLDOWN=1
      log "ИИ замерл — отправлено: продолжай задачу"
    fi
  fi

  # сброс кулдауна на следующем цикле (не шлём 'продолжай' сразу после собственного действия)
  if [ "$COOLDOWN" -eq 1 ]; then COOLDOWN=0; fi
  LAST_SHA=$SHA
  sleep 60
done
