#!/bin/bash
# tmux_watch_enter.sh — enterwatch v2 (новая рамка TUI: без │/╭, строка ввода «текст█», заголовок «• время»).
# Каждые INTERVAL секунд проверяет сессию $SESSION:0. Все проверки — по последним 5 строкам экрана:
#   1) стартовая фраза ollama (регистронезависимо, вокруг могут быть любые символы):
#      "Try asking the agent to inspect files, run tools, or explain a repo."
#      → лог «Висит стартовая фраза, ничего не делать», действий нет.
#   2) «Thought» + два подряд одинаковых кадра (md5, застывший экран):
#      отправить «Сработал enterwatch. Ты завис на Thought», в лог: программа зависла на Thought.
#   3) «Tell the model what to do instead.» (регистронезависимо) + два подряд одинаковых кадра:
#      отправить «ты завис на Tell the model what to do instead (возможно пользователь нажал на паузу)»,
#      в лог: программа зависла на Tell the model what to do instead. Возможно была пауза.
#   4) «[Сообщение из скрипта selfshot» (регистронезависимо, квадратная скобка в начале), два кадра подряд:
#      отправить Enter 3 раза: tmux send-keys -t "$SESSION" -N 3 -K Enter.
#   5) err/Err/error/Error, два кадра подряд (застывший экран):
#      отправить «Сработал enterwatch на error.», записать в лог.
#   6) «⏹ остановка» две проверки подряд: только лог «⏹ остановка. Ничего не делать».

export LC_ALL=C.UTF-8
SESSION=${ENTERWATCH_SESSION:-orchestrator-this-is-your-own-tmux-send-pictures-here-with-task}
TARGET="${SESSION}:0"
LOG=${ENTERWATCH_LOG:-/tmp/tmux_watch_enter.log}
INTERVAL=${ENTERWATCH_INTERVAL:-40}   # проверка каждые N секунд
DURATION=${ENTERWATCH_DURATION:-28000}  # время работы в секундах
STATE=${ENTERWATCH_STATE:-/tmp/tmux_watch_enter.state}      # база для per-rule состояния
HASHF=${ENTERWATCH_HASHFILE:-/tmp/tmux_watch_enter.screencode}    # md5 экрана прошлого цикла
STREAKF=${ENTERWATCH_STREAKFILE:-/tmp/tmux_watch_enter.streak}   # счётчик одинаковых кадров подряд
MIN_FRAMES=${ENTERWATCH_MINFRAMES:-2}  # «две проверки подряд» = 2 идентичных кадра подряд
DRYRUN=${ENTERWATCH_DRYRUN:-0}          # 1 — не отправлять клавиши, только лог решений

# Фразы-маркеры (используются как регистронезависимые подстроки)
START_RE='try asking the agent to inspect files, run tools, or explain a repo'   # стартовая фраза ollama
TH_WORD='thought'                       # слово Thought (целым словом, регистронезависимо)
TELL_STR='tell the model what to do instead'         # регистронезависимо
SELF_STR='[сообщение из скрипта selfshot'            # квадратная скобка в начале
ERR_RE='err|Err|error|Error'             # только эти четыре написания (по спецификации)
STOP_STR='⏹ остановка'                  # точная подстрока

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"; }

# --- Блок замены старого экземпляра (без изменений) ---
PIDF=${ENTERWATCH_PIDFILE:-/tmp/tmux_watch_enter.pid}
SELF=$(readlink -f "$0")
CANDS=$( { cat "$PIDF" 2>/dev/null; pgrep -f "tmux_watch_enter\.sh"; } | grep -v "^$$\$" | sort -u )
OLDS=""
for c in $CANDS; do
  A1=$(ps -p "$c" -o args= 2>/dev/null)
  [ -z "$A1" ] && continue
  # Точное совпадение: bash <абсолютный путь>
  if [ "$A1" = "bash $SELF" ]; then OLDS="$OLDS$c"; continue; fi
  # Запуск по относительному пути (bash ./tmux_watch_enter.sh из scripts/):
  case "$A1" in
    *" tmux_watch_enter.sh")
      CW=$(readlink -f "/proc/$c/cwd" 2>/dev/null) || true
      [ "$CW/tmux_watch_enter.sh" = "$SELF" ] && OLDS="$OLDS$c"
      ;;
  esac
done
if [ -n "${OLDS:-}" ]; then
  for OLD in $OLDS; do pkill -TERM -P "$OLD" 2>/dev/null || true; done
  for OLD in $OLDS; do kill "$OLD" 2>/dev/null && log "заменён старый экземпляр pid=$OLD"; done
  sleep 1
  for OLD in $OLDS; do kill -0 "$OLD" 2>/dev/null && { pkill -KILL -P "$OLD" 2>/dev/null || true; kill -9 "$OLD" 2>/dev/null; log "старый экземпляр pid=$OLD завершён принудительно"; }; done
  for i in 1 2 3 4 5; do
    AL=0; for OLD in $OLDS; do kill -0 "$OLD" 2>/dev/null && AL=1; done
    [ "${AL:-0}" = 0 ] && break; sleep 1
  done
fi

exec 9> "${ENTERWATCH_LOCK:-/tmp/tmux_watch_enter.lock}" || exit
LOCKOK=0; for i in $(seq 1 20); do flock -n 9 && { LOCKOK=1; break; }; sleep 1; done
[ "$LOCKOK" = 1 ] || { log "второй экземпляр завершён (flock занят >20s)"; exit 0; }
echo $$ > "$PIDF"
trap '[ "$(cat "$PIDF" 2>/dev/null)" = "$$" ] && rm -f "$PIDF"' EXIT
trap 'exit 143' TERM INT

END_TS=$(( $(date +%s) + DURATION ))
CYCLE=0
log "=== enter-watch v2 запущен (pid $$), интервал ${INTERVAL}s, dryrun=${DRYRUN} ==="

strip_ansi() { sed -E 's/\x1b\[[0-9;]*[A-Za-z]//g; s/\x1b\][^\r\n]*(\\.|$)//g'; }

# Отправка клавиш: в DRYRUN только лог.
send_keys_safe() {
  if [ "$DRYRUN" = "1" ]; then
    log "цикл $CYCLE: dryrun send-keys: $*"
    return 0
  fi
  tmux send-keys -t "$SESSION" "$@" || { log "цикл $CYCLE: err ошибка при отправке клавиш"; return 1; }
}

while [ "$(date +%s)" -lt "$END_TS" ]; do
  CYCLE=$((CYCLE+1))
  CHECK_START=$(date +%s)

  SCREEN=$(tmux capture-pane -t "$TARGET" -p 2>/dev/null | strip_ansi)
  if [ -z "$SCREEN" ]; then
    log "цикл $CYCLE: capture пуст (сессия мертва?) — пропускаем"
    sleep "$INTERVAL"
    continue
  fi

  # Строка ввода в новой рамке: последняя строка, содержащая блочный курсор █.
  INPUT_LINE=$(echo "$SCREEN" | grep '█' | tail -1) || true
  INPUT=$(printf '%s\n' "${INPUT_LINE:-}" | tr -d '[:space:]█')          # только текст без пробелов/курсора
  INPUT_CLEAN=$(printf '%s\n' "${INPUT_LINE:-}" | sed 's/█//g; s/[[:space:]]\{1,\}/ /g; s/^ //; s/ $//')

  # --- Детект паузы (md5 экрана, streak-based) ---
  PREV_HASH=$(cat "$HASHF" 2>/dev/null) || true
  # HASHSCREEN: экран без анимируемого хрома («Working...») и без курсорной строки █ —
  # иначе md5 не совпадёт между циклами даже при застывшем экране. Текст ввода
  # добавляем в хэш отдельно ($INPUT): набор текста сбрасывает streak, пока пользователь печатает.
  HASHSCREEN=$(printf '%s\n' "$SCREEN" \
    | grep -vE '^[[:space:]]*Working[.\-]{0,6}[[:space:]]*$' \
    | sed -E '/█/s/.*/IN/')
  CUR_HASH=$(printf '%s|IN:%s\n' "$HASHSCREEN" "$INPUT" | md5sum | awk '{print $1}')

  if [ -n "$PREV_HASH" ] && [ "$PREV_HASH" = "$CUR_HASH" ]; then
    STREAK=$(( $(cat "$STREAKF" 2>/dev/null || echo 1) + 1 ))
  else
    STREAK=1
  fi
  printf '%s' "$STREAK" > "$STREAKF"
  FROZEN=0; [ "$STREAK" -ge "$MIN_FRAMES" ] && FROZEN=1
  printf '%s' "$CUR_HASH" > "$HASHF"

  # Последние 5 значимых строк (исключая пустые/беловые — padding рамки не вытесняет контент).
  # Пример: pane 21 строка, Thought на 16-й, а последние 5 физических = blanks+курсор+статус.
  LAST5=$(printf '%s\n' "$SCREEN" | grep -v '^[[:space:]]*$' | tail -n 5)
  # Склеенные последние 5 строк (переносы → одиночный пробел) — чтобы фраза,
  # разорванная переносом, тоже совпала; внутристрочные пробелы фразы сохраняются.
  LAST5J=$(printf '%s\n' "$LAST5" | tr '\n' ' ' | sed 's/[[:space:]]\{1,\}/ /g')

  ACTED=0

  # --- Правило 1: стартовая фраза ollama — только лог, ничего не делать ---
  if printf '%s\n' "$LAST5J" | grep -qiF "$START_RE"; then
    log "цикл $CYCLE: Висит стартовая фраза, ничего не делать"
    ACTED=1
  fi

  TH_STATE="${STATE}.thought"
  TELL_STATE="${STATE}.tell_model"
  SELF_STATE="${STATE}.selfshot"
  ERR2_STATE="${STATE}.err2"

  if [ "$FROZEN" = "1" ]; then
    # --- Правило 2: «Thought» + два подряд одинаковых кадра (застывший экран) ---
    if printf '%s\n' "$LAST5" | grep -qwEi "$TH_WORD"; then
      PREVT=$(cat "$TH_STATE" 2>/dev/null) || true
      if [ "$CUR_HASH" != "$PREVT" ]; then
        sleep 1
        send_keys_safe "Сработал enterwatch. Ты завис на Thought" C-m \
          && { printf '%s' "$CUR_HASH" > "$TH_STATE"; log "цикл $CYCLE: программа зависла на Thought (два кадра подряд) → отправлено сообщение"; ACTED=1; }
      fi
    else
      rm -f "$TH_STATE"
    fi

    # --- Правило 3: «Tell the model what to do instead.» + два кадра подряд ---
    if printf '%s\n' "$LAST5J" | grep -qiF "$TELL_STR"; then
      PREVT=$(cat "$TELL_STATE" 2>/dev/null) || true
      if [ "$CUR_HASH" != "$PREVT" ]; then
        sleep 1
        send_keys_safe "ты завис на Tell the model what to do instead (возможно пользователь нажал на паузу)" C-m \
          && { printf '%s' "$CUR_HASH" > "$TELL_STATE"; log "цикл $CYCLE: программа зависла на Tell the model what to do instead. Возможно была пауза → отправлено сообщение"; ACTED=1; }
      fi
    else
      rm -f "$TELL_STATE"
    fi

    # --- Правило 4: «[Сообщение из скрипта selfshot» два кадра подряд → Enter ×3 ---
    if printf '%s\n' "$LAST5J" | grep -qiF "$SELF_STR"; then
      PREVT=$(cat "$SELF_STATE" 2>/dev/null) || true
      if [ "$CUR_HASH" != "$PREVT" ]; then
        sleep 1
        send_keys_safe "-N" "3" "-K" Enter \
          && { printf '%s' "$CUR_HASH" > "$SELF_STATE"; log "цикл $CYCLE: selfshot-маркер два кадра подряд → отправлены 3×Enter"; ACTED=1; }
      fi
    else
      rm -f "$SELF_STATE"
    fi

    # --- Правило 5: err/Err/error/Error, два кадра подряд (застывший экран) ---
    if printf '%s\n' "$LAST5" | grep -E "$ERR_RE"; then
      PREVT=$(cat "$ERR2_STATE" 2>/dev/null) || true
      if [ "$CUR_HASH" != "$PREVT" ]; then
        sleep 1
        send_keys_safe "Сработал enterwatch на error." C-m \
          && { printf '%s' "$CUR_HASH" > "$ERR2_STATE"; log "цикл $CYCLE: Сработал enterwatch на error (два кадра подряд) → отправлено сообщение, записано в лог"; ACTED=1; }
      fi
    else
      rm -f "$ERR2_STATE"
    fi
  else
    # Не застывший экран — сброс per-rule состояний, чтобы сработало заново при новом зависании.
    rm -f "$TH_STATE" "$TELL_STATE" "$SELF_STATE" "$ERR2_STATE"
  fi

  # --- Правило 6: «⏹ остановка» две проверки подряд — только лог (1 раз за эпизод) ---
  STOP_PREVF="${STATE}.stopprev"
  if printf '%s\n' "$LAST5J" | grep -qiF "$STOP_STR"; then
    PREV=$(cat "$STOP_PREVF" 2>/dev/null) || true
    if [ "$PREV" = "seen" ]; then
      log "цикл $CYCLE: ⏹ остановка. Ничего не делать"
      printf 'logged' > "$STOP_PREVF"
    elif [ -z "$PREV" ]; then
      printf 'seen' > "$STOP_PREVF"
    fi
  else
    rm -f "$STOP_PREVF"
  fi

  # --- Логируем «ок», если ничего не сработало ---
  if [ "$ACTED" = "0" ] && [ "$FROZEN" != "1" ]; then
    log "цикл $CYCLE: ок (ввод: «${INPUT_CLEAN:-пусто}», маркеров нет, не застывший экран)"
  elif [ "$ACTED" = "0" ] && [ "$FROZEN" = "1" ] && [ -n "${INPUT_CLEAN:-}" ]; then
    log "цикл $CYCLE: FROZEN, во вводе текст «$INPUT_CLEAN», но маркеров нет — ждём"
  fi

  # Сон до следующего интервала
  REMAIN=$(( INTERVAL - ( $(date +%s) - CHECK_START ) ))
  while [ "$REMAIN" -gt 0 ] && [ "$(date +%s)" -lt "$END_TS" ]; do
    sleep $(( REMAIN > 5 ? 5 : REMAIN ))
    REMAIN=$(( INTERVAL - ( $(date +%s) - CHECK_START ) ))
  done
done

log "=== enter-watch остановлен после $CYCLE циклов ==="
