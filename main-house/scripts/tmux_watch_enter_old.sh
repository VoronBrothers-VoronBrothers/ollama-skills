#!/bin/bash
# tmux_watch_enter.sh — раз в INTERVAL секунд проверяем сессию оркестратора.
# 1) Если в строке ввода лежит неотправленный текст — ждём 1 секунду и нажимаем Enter.
# 2) Если экран заканчивается на строку-маркер размышления «Thought» (бывало с буллетом «•», теперь без него)
#    и модель зависла — отправляем "." + Enter.
# 3) Если экран заканчивается на фразу «Tell the model what to do instead» и модель зависла — отправляем "." + Enter.
# 4) Если агент на ПАУЗЕ (экран не меняется) и есть ошибки в истории — отправляем пинг-сообщение.

export LC_ALL=C.UTF-8
S="${ENTERWATCH_SESSION:-orchestrator-this-is-your-own-tmux-send-pictures-here-with-task}"
LOG=${ENTERWATCH_LOG:-/tmp/tmux_watch_enter.log}
INTERVAL=${ENTERWATCH_INTERVAL:-40}   # проверка каждые N секунд
DURATION=28000                          # время работы в секундах
STATE=${ENTERWATCH_STATE:-/tmp/tmux_watch_enter.errstate}    # последние «виденные» err-строки
HASHF=${ENTERWATCH_HASHFILE:-/tmp/tmux_watch_enter.screencode} # md5 экрана прошлого цикла
STREAKF=${ENTERWATCH_STREAKFILE:-/tmp/tmux_watch_enter.streak}   # счётчик одинаковых кадров подряд
MIN_FRAMES=${ENTERWATCH_MINFRAMES:-3}  # сколько одинаковых кадров нужно для FROZEN (дефолт 3 ≈ 2 мин)

# Регулярка на ошибки: только вхождения err / Error / error
# (Traceback, Panic, Exception и т.п. НЕ считаются — по требованию пользователя)
ERR_RE='err|Error|error'


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
  # резолвим через cwd кандидата и сравниваем с SELF.
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
log "=== enter-watch запущен (pid $$), интервал ${INTERVAL}s ==="

strip_ansi() { sed -E 's/\x1b\[[0-9;]*[A-Za-z]//g; s/\x1b\][^\r\n]*(\\.|$)//g'; }

while [ "$(date +%s)" -lt "$END_TS" ]; do
  CYCLE=$((CYCLE+1))
  CHECK_START=$(date +%s)

  # Получаем экран и историю
  SCREEN=$(tmux capture-pane -t "$S" -p 2>/dev/null | strip_ansi)
  HISTORY=$(tmux capture-pane -t "$S" -pS -50 2>/dev/null | strip_ansi)

  if [ -z "$SCREEN" ]; then
    log "цикл $CYCLE: capture пуст (сессия мертва?) — пропускаем"
    sleep "$INTERVAL"
    continue
  fi

  # Строка ввода (в рамке │...│)
  INPUT_LINE=$(echo "$SCREEN" | grep '^│.*│$' | sed 's/^│//; s/│$//' | sed 's/█//g')
  INPUT=$(printf '%s' "$INPUT_LINE" | tr -d '[:space:]')
  # Очищаем строку ввода для лога: повторяющиеся пробелы→один, края обрезаются.
  # В лог пишем ТОЧНЫЙ текст из поля ввода (что именно шло на отправку).
  INPUT_CLEAN=$(printf '%s' "$INPUT_LINE" | sed 's/[[:space:]]\{1,\}/ /g; s/^ //; s/ $//')

  # --- Детект паузы (хэширование экрана, streak-based) ---
  PREV_HASH=$(cat "$HASHF" 2>/dev/null) || true
  # HASHSCREEN: экран без анимируемого хрома (спиннер "Working.."), иначе md5 не совпадёт
  # между циклами и FROZEN=1 недостижим даже при зависании модели. Строку ввода целиком
  # заменяем на константу, но ЕЁ ТЕКСТ добавляем в хэш отдельно ($INPUT): мигающий курсор █
  # не ломает хэш (он стирается пробелами), а вот набор текста сбрасывает streak —
  # иначе enterwatch шлёт Enter посреди фразы, пока пользователь ещё печатает.
  HASHSCREEN=$(printf '%s\n' "$SCREEN" \
    | grep -vE '^[[:space:]]*Working\.([.]){0,3}[[:space:]]*$' \
    | sed -E 's/[[:space:]]*│.*$/INPUTLINE/')
  CUR_HASH=$(printf '%s|IN:%s\n' "$HASHSCREEN" "$INPUT" | md5sum | awk '{print $1}')
  # Streak: сколько кадров подряд идентичны (нужно >= MIN_FRAMES для FROZEN)
  if [ -n "$PREV_HASH" ] && [ "$PREV_HASH" = "$CUR_HASH" ]; then
    STREAK=$(( $(cat "$STREAKF" 2>/dev/null || echo 1) + 1 ))
  else
    STREAK=1
  fi
  printf '%s' "$STREAK" > "$STREAKF"
  FROZEN=0; [ "$STREAK" -ge "$MIN_FRAMES" ] && FROZEN=1
  printf '%s' "$CUR_HASH" > "$HASHF"

  # --- ЛОГИКА: зависание на "Thought" или "Tell the model what to do instead" ---
  TH_STATE="${STATE}.thought"
  TELL_STATE="${STATE}.tell_model"
  if [ "$FROZEN" = "1" ]; then
    LAST_CONTENT=$(echo "$SCREEN" | sed '/^╭/,$d' | grep -vE '^[[:space:]]*$' | tail -n 1)

    # 1) Маркер "Thought" (с буллетом или без)
    if echo "$LAST_CONTENT" | grep -qE '^[[:space:]]*([•●][[:space:]]+)?[Tt]h(o|in)[a-z]*$'; then
      PREVT=$(cat "$TH_STATE" 2>/dev/null) || true
      if [ "$CUR_HASH" != "$PREVT" ]; then
        sleep 1
        if tmux send-keys -t "$S" "." C-m; then
          printf '%s' "$CUR_HASH" > "$TH_STATE"
          log "цикл $CYCLE: завис на Thought (экран заморожен) → отправлена точка"
        else
          log "цикл $CYCLE: err ошибка при отправке точки (Thought)"
        fi
      fi
    else
      rm -f "$TH_STATE"
    fi

    # 2) Маркер "Tell the model what to do instead" (регистронезависимо, точка опциональна)
    if echo "$LAST_CONTENT" | grep -qiF "Tell the model what to do instead"; then
      PREVT=$(cat "$TELL_STATE" 2>/dev/null) || true
      if [ "$CUR_HASH" != "$PREVT" ]; then
        sleep 1
        if tmux send-keys -t "$S" "." C-m; then
          printf '%s' "$CUR_HASH" > "$TELL_STATE"
          log "цикл $CYCLE: завис на Tell the model... (экран заморожен) → отправлена точка"
        else
          log "цикл $CYCLE: err ошибка при отправке точки (Tell the model)"
        fi
      fi
    else
      rm -f "$TELL_STATE"
    fi
  fi

  # --- Enter: неотправленный текст в строке ввода (только если FROZEN — два md5 совпали) ---
  if [ -n "$INPUT" ]; then
    if [ "$FROZEN" = "1" ]; then
      sleep 1
      if tmux send-keys -t "$S" C-m; then
        log "цикл $CYCLE: warning ОТПРАВЛЕНО (Enter/C-m), текст во вводе: «$INPUT_CLEAN» "
        : > "$STATE"; rm -f "${STATE}.pinged"
      else
        log "цикл $CYCLE: err ошибка при отправке Enter"
      fi
    else
      log "цикл $CYCLE: текст во вводе: «$INPUT_CLEAN» но не FROZEN (md5 различается) — ждём ещё цикл"
    fi
  else
    # --- Err-детект по истории + видимому экрану (только если ввод пуст и не сработал Thought) ---
    PINGED="${STATE}.pinged"
    # Детект по последним 8 строкам видимого экрана (не весь скроллбек — меньше шума из истории)
    ERRS=$(echo "$SCREEN" | tail -n 8 | grep -E "$ERR_RE") || true

    if [ -z "$ERRS" ] && [ ! -s "$STATE" ]; then
      log "цикл $CYCLE: ок (ввод пуст, еррор нет, thought чист)"
    fi

    if [ -n "$ERRS" ]; then
      PREV=$(cat "$STATE" 2>/dev/null)
      if [ "$ERRS" != "$PREV" ]; then
        printf '%s\n' "$ERRS" > "$STATE"; rm -f "$PINGED"
      fi
      if [ "$FROZEN" = "1" ] && [ ! -e "$PINGED" ]; then
        sleep 1
        tmux send-keys -t "$S" "[отработал перезапуск через enterwatch из-за ерр/еррор в истории]" C-m && { touch "$PINGED"; log "цикл $CYCLE: err-сигнал на паузе → отправлен перезапуск"; } || log "цикл $CYCLE: ошибка при отправке точки"
      else
        [ "$FROZEN" = "1" ] || log "цикл $CYCLE: err в истории, но не пауза — ждём"
      fi
    elif [ -n "$(cat "$STATE" 2>/dev/null)" ]; then
      : > "$STATE"; rm -f "$PINGED"
    fi
  fi

  # Сон до следующего интервала
  REMAIN=$(( INTERVAL - ( $(date +%s) - CHECK_START ) ))
  while [ "$REMAIN" -gt 0 ] && [ "$(date +%s)" -lt "$END_TS" ]; do
    sleep $(( REMAIN > 5 ? 5 : REMAIN ))
    REMAIN=$(( INTERVAL - ( $(date +%s) - CHECK_START ) ))
  done
done

log "=== enter-watch остановлен после $CYCLE циклов ==="
