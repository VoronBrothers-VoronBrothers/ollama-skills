#!/bin/bash
# tmux_watch_enter.sh — раз в 5 минут (всего 5 часов) проверяем сессию оркестратора.
# Если в строке ввода лежит неотправленный текст — ждём 1 секунду и нажимаем Enter (C-m).
export LC_ALL=C.UTF-8
S="orchestrator-this-is-your-own-tmux-send-pictures-here-with-task"
LOG=/tmp/tmux_watch_enter.log
INTERVAL=300          # проверка каждые 5 минут
DURATION=18000         # работаем 5 часов (18000 секунд)

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"; }

# самозащита: если уже есть живой экземпляр — второй тихо выходит
exec 9> /tmp/tmux_watch_enter.lock || exit
flock -n 9 || { log "второй экземпляр завершён (уже запущен)"; exit 0; }

END_TS=$(( $(date +%s) + DURATION ))
CYCLE=0
log "=== enter-watch запущен (pid $$), интервал ${INTERVAL}s, длительность $(( DURATION / 3600 ))ч ==="

while [ "$(date +%s)" -lt "$END_TS" ]; do
  CYCLE=$((CYCLE+1))
  CHECK_START=$(date +%s)
  SCREEN=$(tmux capture-pane -t "$S" -p 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | col -b)
  if [ -z "$SCREEN" ]; then
    log "цикл $CYCLE: capture пуст (сессия мертва?) — пропускаем"
    sleep "$INTERVAL"
    continue
  fi

  # Строка ввода: строки в рамке │...│ → убираем рамку, курсор █ и пробелы
  INPUT=$(echo "$SCREEN" | grep '^│.*│$' | sed 's/^│//; s/│$//' | sed 's/█//g' | tr -d '[:space:]')

  if [ -n "$INPUT" ]; then
    # есть неотправленный текст — задержка 1 секунда, затем Enter (C-m)
    sleep 1
    tmux send-keys -t "$S" C-m && log "цикл $CYCLE: ОТПРАВЛЕНО (Enter/C-m): $INPUT" \
      || log "цикл $CYCLE: ошибка при отправке Enter"
  else
    log "цикл $CYCLE: строка ввода пуста, Enter не нужен"
  fi

  # спим до следующего интервала короткими снами — чтобы не проспать конец окна
  REMAIN=$(( INTERVAL - ( $(date +%s) - CHECK_START ) ))
  while [ "$REMAIN" -gt 0 ] && [ "$(date +%s)" -lt "$END_TS" ]; do
    sleep $(( REMAIN > 5 ? 5 : REMAIN ))
    REMAIN=$(( INTERVAL - ( $(date +%s) - CHECK_START ) ))
  done
done

log "=== enter-watch остановлен после $CYCLE циклов ==="
