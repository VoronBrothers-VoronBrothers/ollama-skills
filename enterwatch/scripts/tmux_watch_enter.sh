#!/bin/bash
# tmux_watch_enter.sh — раз в INTERVAL секунд (всего 5 часов) проверяем сессию оркестратора.
# 1) Если в строке ввода лежит неотправленный текст — ждём 1 секунду и нажимаем Enter (C-m).
# 2) Если агент на ПАУЗЕ (видимый экран не менялся с прошлого цикла), в истории (видимая часть + скроллбек -S -50)
#    появились новые err-строки — отправляем «.» + Enter как пинг: сообщение дойдёт [из очереди], агент перезапустится.
#    Повторные пинги на тот же набор err исключены (state).
export LC_ALL=C.UTF-8
S="${ENTERWATCH_SESSION:-orchestrator-this-is-your-own-tmux-send-pictures-here-with-task}"
LOG=${ENTERWATCH_LOG:-/tmp/tmux_watch_enter.log}
INTERVAL=${ENTERWATCH_INTERVAL:-300}   # проверка каждые N секунд (по умолчанию 5 минут)
DURATION=18000                          # работаем 5 часов (18000 секунд)
STATE=${ENTERWATCH_STATE:-/tmp/tmux_watch_enter.errstate}    # последние «виденные» err-строки
HASHF=${ENTERWATCH_HASHFILE:-/tmp/tmux_watch_enter.screencode} # md5 экрана прошлого цикла (детект паузы)

# Регулярка на типовые ошибки: standalone 'err'/'Err', error/Error, known phrase, traceback, panic, exception.
ERR_RE='(^|[[:space:]])Err?([[:space:]]|$)|[Ee]rror|expected element type|[Tt]raceback|[Pp]anic|[Ee]xception'

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"; }

# самозащита: если уже есть живой экземпляр — второй тихо выходит
exec 9> "${ENTERWATCH_LOCK:-/tmp/tmux_watch_enter.lock}" || exit
flock -n 9 || { log "второй экземпляр завершён (уже запущен)"; exit 0; }

END_TS=$(( $(date +%s) + DURATION ))
CYCLE=0
log "=== enter-watch запущен (pid $$), интервал ${INTERVAL}s, длительность $(( DURATION / 3600 ))ч ==="

while [ "$(date +%s)" -lt "$END_TS" ]; do
  CYCLE=$((CYCLE+1))
  CHECK_START=$(date +%s)
  SCREEN=$(tmux capture-pane -t "$S" -p 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | col -b)
  HISTORY=$(tmux capture-pane -t "$S" -pS -50 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')
  if [ -z "$SCREEN" ]; then
    log "цикл $CYCLE: capture пуст (сессия мертва?) — пропускаем"
    sleep "$INTERVAL"
    continue
  fi

  # Строка ввода: строки в рамке │...│ → убираем рамку, курсор █ и пробелы
  INPUT=$(echo "$SCREEN" | grep '^│.*│$' | sed 's/^│//; s/│$//' | sed 's/█//g' | tr -d '[:space:]')

  # --- детект паузы: видимый экран не менялся с прошлого цикла → агент заморожен.
  # (в tmux 3.6 переменная pane_inactivity_time пустая и ненадёжная, поэтому хэшируем экран) ---
  PREV_HASH=$(cat "$HASHF" 2>/dev/null) || true
  CUR_HASH=$(printf '%s' "$SCREEN" | md5sum | awk '{print $1}')
  FROZEN=0; [ -n "$PREV_HASH" ] && [ "$PREV_HASH" = "$CUR_HASH" ] && FROZEN=1
  printf '%s' "$CUR_HASH" > "$HASHF"

  # --- Enter: неотправленный текст в строке ввода ---
  if [ -n "$INPUT" ]; then
    sleep 1
    tmux send-keys -t "$S" C-m && log "цикл $CYCLE: ОТПРАВЛЕНО (Enter/C-m): $INPUT" \
      || log "цикл $CYCLE: ошибка при отправке Enter"
  else
    # --- err-детект по истории + видимому экрану (только если ввод пуст) ---
    PINGED="${STATE}.pinged"   # метка: на этот набор err точка уже отправлена
    ERRS=$( { echo "$HISTORY"; } | grep -E "$ERR_RE" | sed '/^$/d' ) || true
    if [ -z "$ERRS" ] && [ ! -s "$STATE" ]; then
      log "цикл $CYCLE: ок (ввод пуст, err нет)"
    fi
    if [ -n "$ERRS" ]; then
      PREV=$(cat "$STATE" 2>/dev/null)
      if [ "$ERRS" != "$PREV" ]; then   # набор err изменился → сброс метки, новый пинг разрешён
        printf '%s\n' "$ERRS" > "$STATE"; rm -f "$PINGED"
      fi
      if [ "$FROZEN" = "1" ] && [ ! -e "$PINGED" ]; then
        sleep 1
        tmux send-keys -t "$S" "." C-m           && { touch "$PINGED"; log "цикл $CYCLE: err-сигнал на паузе → отправлена точка (state: $(head -c 60 "$STATE"))"; }           || log "цикл $CYCLE: ошибка при отправке точки"
      else
        [ "$FROZEN" = "1" ] || log "цикл $CYCLE: err в истории, но не пауза — ждём"
      fi
    elif [ -n "$(cat "$STATE" 2>/dev/null)" ]; then
      : > "$STATE"; rm -f "$PINGED"   # err-строк сошли с экрана — сброс state
    fi
  fi

  # спим до следующего интервала короткими снами — чтобы не проспать конец окна
  REMAIN=$(( INTERVAL - ( $(date +%s) - CHECK_START ) ))
  while [ "$REMAIN" -gt 0 ] && [ "$(date +%s)" -lt "$END_TS" ]; do
    sleep $(( REMAIN > 5 ? 5 : REMAIN ))
    REMAIN=$(( INTERVAL - ( $(date +%s) - CHECK_START ) ))
  done
done

log "=== enter-watch остановлен после $CYCLE циклов ==="
