#!/bin/bash
# tmux_watch_enter.sh — раз в INTERVAL секунд (всего 5 часов) проверяем сессию оркестратора.
# 1) Если в строке ввода лежит неотправленный текст — ждём 1 секунду и нажимаем Enter (C-m).
# 2) Если агент на ПАУЗЕ (видимый экран не менялся с прошлого цикла), в истории (видимая часть + скроллбек -S -50)
#    появились новые err-строки — отправляем «.» + Enter как пинг: сообщение дойдёт [из очереди], агент перезапустится.
#    Повторные пинги на тот же набор err исключены (state).
export LC_ALL=C.UTF-8
S="${ENTERWATCH_SESSION:-orchestrator-this-is-your-own-tmux-send-pictures-here-with-task}"
LOG=${ENTERWATCH_LOG:-/tmp/tmux_watch_enter.log}
INTERVAL=${ENTERWATCH_INTERVAL:-250}   # проверка каждые N секунд
DURATION=28000                          # работаем ? часов (по умолчанию было: 18000 секунд)
STATE=${ENTERWATCH_STATE:-/tmp/tmux_watch_enter.errstate}    # последние «виденные» err-строки
HASHF=${ENTERWATCH_HASHFILE:-/tmp/tmux_watch_enter.screencode} # md5 экрана прошлого цикла (детект паузы)

# Регулярка на типовые ошибки: standalone 'err'/'Err', error/Error, known phrase, traceback, panic, exception.
ERR_RE='(^|[[:space:]])Err?([[:space:]]|$)|[Ee]rror|expected element type|[Tt]raceback|[Pp]anic|[Ee]xception'

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"; }

# Режим замены: новый запуск убивает старый живой экземпляр → время работы обновляется с нуля.
# Кандидаты: pidfile (с проверкой cmdline — защита от переезда PID) + pgrep как fallback на старые экземпляры.
PIDF=${ENTERWATCH_PIDFILE:-/tmp/tmux_watch_enter.pid}
SELF=$(readlink -f "$0")   # канонический путь скрипта для строгого match
# Кандидаты: pidfile + pgrep по тексту; дальше строгая проверка ps args= —
# иначе wrapper-процессы, чей cmdline лишь содержит путь к скрипту, попадут под kill.
CANDS=$( { cat "$PIDF" 2>/dev/null; pgrep -f "tmux_watch_enter\.sh"; } | grep -v "^$$\$" | sort -u )
OLDS=""
for c in $CANDS; do
  A1=$(ps -p "$c" -o args= 2>/dev/null)
  [ "$A1" = "bash $SELF" ] && OLDS="$OLDS$c"
done
if [ -n "${OLDS:-}" ]; then
  for OLD in $OLDS; do pkill -TERM -P "$OLD" 2>/dev/null || true; done   # дети наследуют lock fd — чистить первыми
  for OLD in $OLDS; do kill "$OLD" 2>/dev/null && log "заменён старый экземпляр pid=$OLD"; done
  sleep 1   # bash может отложить TERM на время сна — даём шанс
  for OLD in $OLDS; do kill -0 "$OLD" 2>/dev/null && { pkill -KILL -P "$OLD" 2>/dev/null || true; kill -9 "$OLD" 2>/dev/null; log "старый экземпляр pid=$OLD завершён принудительно"; }; done
  # ждём, пока ядро закроет fd и отпустит flock (зациклено до ~5с)
  for i in 1 2 3 4 5; do
    AL=0; for OLD in $OLDS; do kill -0 "$OLD" 2>/dev/null && AL=1; done
    [ "${AL:-0}" = 0 ] && break; sleep 1
  done
fi


# самозащита: flock. После убийства старого экземпляра его дети могут ещё ~5с держать
# lock-fd (sleep без CLOEXEC) — повторяем, прежде чем сдаваться.
exec 9> "${ENTERWATCH_LOCK:-/tmp/tmux_watch_enter.lock}" || exit
LOCKOK=0; for i in $(seq 1 20); do flock -n 9 && { LOCKOK=1; break; }; sleep 1; done
[ "$LOCKOK" = 1 ] || { log "второй экземпляр завершён (flock занят >20s)"; exit 0; }
echo $$ > "$PIDF"
trap '[ "$(cat "$PIDF" 2>/dev/null)" = "$$" ] && rm -f "$PIDF"' EXIT
trap 'exit 143' TERM INT   # штатное завершение: EXIT-трап очистит pidfile

END_TS=$(( $(date +%s) + DURATION ))
CYCLE=0
log "=== enter-watch запущен (pid $$), интервал ${INTERVAL}s, длительность $(( DURATION / 3600 ))ч ==="

strip_ansi() { sed -E 's/\x1b\[[0-9;]*[A-Za-z]//g; s/\x1b\][^\r\n]*(\\.|$)//g'; }   # без зависимости от col

while [ "$(date +%s)" -lt "$END_TS" ]; do
  CYCLE=$((CYCLE+1))
  CHECK_START=$(date +%s)
  SCREEN=$(tmux capture-pane -t "$S" -p 2>/dev/null | strip_ansi)
  HISTORY=$(tmux capture-pane -t "$S" -pS -50 2>/dev/null | strip_ansi)
  if [ -z "$SCREEN" ]; then
    log "цикл $CYCLE: capture пуст (сессия мертва?) — пропускаем"
    sleep "$INTERVAL"
    continue
  fi

  # Строка ввода: строки в рамке │...│ → убираем рамку и курсор █ (пробелы сохраняем для лога)
  INPUT_LINE=$(echo "$SCREEN" | grep '^│.*│$' | sed 's/^│//; s/│$//' | sed 's/█//g')
  INPUT=$(printf '%s' "$INPUT_LINE" | tr -d '[:space:]')

  # --- детект паузы: видимый экран не менялся с прошлого цикла → агент заморожен.
  # (в tmux 3.6 переменная pane_inactivity_time пустая и ненадёжная, поэтому хэшируем экран) ---
  PREV_HASH=$(cat "$HASHF" 2>/dev/null) || true
  CUR_HASH=$(printf '%s' "$SCREEN" | md5sum | awk '{print $1}')
  FROZEN=0; [ -n "$PREV_HASH" ] && [ "$PREV_HASH" = "$CUR_HASH" ] && FROZEN=1
  printf '%s' "$CUR_HASH" > "$HASHF"

  # --- Enter: неотправленный текст в строке ввода ---
  if [ -n "$INPUT" ]; then
    sleep 1
    if tmux send-keys -t "$S" C-m; then
      log "цикл $CYCLE: warning ОТПРАВЛЕНО (Enter/C-m): $(printf '%s' "$INPUT_LINE" | sed 's/ *$//')"
      : > "$STATE"; rm -f "${STATE}.pinged"   # экран изменится — сброс err-state
    else
      log "цикл $CYCLE: err ошибка при отправке Enter"
    fi
  else
    # --- err-детект по истории + видимому экрану (только если ввод пуст) ---
    # --- err-детект по истории + видимому экрану (только если ввод пуст) ---
    PINGED="${STATE}.pinged"   # метка: на этот набор err точка уже отправлена
    ERRS=$( { printf '%s\n%s\n' "$SCREEN" "$HISTORY"; } | grep -E "$ERR_RE" | sort -u ) || true
    if [ -z "$ERRS" ] && [ ! -s "$STATE" ]; then
      log "цикл $CYCLE: ок (ввод пуст, еррор нет)"
    fi
    if [ -n "$ERRS" ]; then
      PREV=$(cat "$STATE" 2>/dev/null)
      if [ "$ERRS" != "$PREV" ]; then   # набор err изменился → сброс метки, новый пинг разрешён
        printf '%s\n' "$ERRS" > "$STATE"; rm -f "$PINGED"
      fi
      if [ "$FROZEN" = "1" ] && [ ! -e "$PINGED" ]; then
        sleep 1
        tmux send-keys -t "$S" "[отработал перезапуск через enterwatch]" C-m           && { touch "$PINGED"; log "цикл $CYCLE: err-сигнал на паузе → отправлен перезапуск (state: $(head -c 60 "$STATE"))"; }           || log "цикл $CYCLE: ошибка при отправке точки"
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
