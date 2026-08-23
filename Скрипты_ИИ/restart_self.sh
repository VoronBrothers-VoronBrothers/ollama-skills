#!/usr/bin/env bash
# ============================================================
#  Самовозобновление оркестратора (задача 0/1/2).
#  Сохраняет состояние -> убивает текущий TUI -> запускает новый
#  TUI с промптом «продолжи, прочитай state.md».
#
#  ВАЖНО: запускать ОТДЕЛЁННО, чтобы пережил смерть своего TUI:
#    setsid bash restart_self.sh </dev/null >/tmp/restart.log 2>&1 &
#
#  Переменные окружения:
#    DRY_RUN=1   — только печать действий, ничего не убивать
#    WAIT_SECS   — сколько ждать завершения текущего хода (default 12)
#    TASK_PROMPT      — промт для новой сессии (default — «продолжи»)
# ============================================================
set -uo pipefail

ROOT="/home/voron/Документы/VB-ollama"
TASKS="$ROOT/Папка заданий для AI"
STATE="$TASKS/state.md"
BOOT="/home/voron/Документы/VB-ollama/Скрипты_ИИ/ollama_console.sh"
LOG="/tmp/restart_$(date +%Y%m%d_%H%M%S).log"
DRY_RUN="${DRY_RUN:-0}"
WAIT_SECS="${WAIT_SECS:-12}"
# ЖЁСТКИЙ ЗАТВОРНИК от бесконечного цикла перезапусков (техническая защита,
# не зависит от поведения модели). Допускаем ТОЛЬКО ОДИН self-restart.
COUNTER_FILE="$TASKS/.restart_count"

log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"; }

# --- 1. Проверка состояния: без state.md не перезапускаемся ---
if [ ! -s "$STATE" ]; then
  log "ОШИБКА: $STATE отсутствует или пуст — отказ в перезапуске (нет состояния)"
  exit 1
fi
log "state.md: $(wc -l < "$STATE") строк / $(wc -c < "$STATE") байт"
log "LOG=$LOG"

# --- 1b. ЗАТВОРНИК: если self-restart уже выполнялся — отказ (анти-цикл) ---
if [ -f "$COUNTER_FILE" ]; then
  prev=$(tr -dc '0-9' < "$COUNTER_FILE" 2>/dev/null); prev=${prev:-0}
  if [ "$prev" -ge 1 ]; then
    log "ОТКАЗ: self-restart уже выполнен (count=$prev). Анти-цикл активен."
    log "Для повторного перезапуска вручную удалите: $COUNTER_FILE"
    exit 0
  fi
fi
log "затворник OK (count=0, перезапуск разрешён)"

# --- 2. Промт для новой сессии ---
TASK_PROMPT="${TASK_PROMPT:-Продолжи работу. Прочитай ${STATE} (состояние: текущая задача, что сделано, что собрано, решения, следующие шаги) и ${TASKS}/tasks.md. Возьми текущую задачу и продолжай с того места, где остановилась предыдущая сессия. НЕ начинай заново — состояние уже в state.md. После каждого шага дописывай прогресс в state.md. Если нужно сохранить состояние и перезапустить себя — загрузи скилл 'save-session' (полная инструкция по памяти+перезапуску).}"

# --- 3. Функция: убить TUI-процессы ollama (кроме 'ollama serve' и llama-server) ---
list_tuis() {
  for pid in $(pgrep -x ollama 2>/dev/null); do
    cmd="$(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null)"
    case "$cmd" in
      *ollama\ serve*) : ;;            # сервер — НЕ трогать (полный путь или "ollama serve")
      *llama-server*) : ;;             # инференс-бэкенд — НЕ трогать (на всякий)
      *) echo "$pid|$cmd" ;;
    esac
  done
}

kill_tuis() {
  local found=0
  while IFS='|' read -r pid cmd; do
    [ -z "$pid" ] && continue
    found=1
    log "kill TUI: PID=$pid CMD=$cmd"
    [ "$DRY_RUN" = 1 ] || kill "$pid" 2>/dev/null
  done < <(list_tuis)
  [ "$found" = 0 ] && log "TUI-процессы не найдены (возможно, уже нет)"
}

# --- 4. Ждём завершения текущего хода ---
log "ожидание ${WAIT_SECS}с (чтобы текущий ответ завершился)..."
[ "$DRY_RUN" = 1 ] || sleep "$WAIT_SECS"

# --- 5. Убиваем TUI ---
kill_tuis

# --- 6. Дожидаемся смерти TUI (до 20с) ---
for i in $(seq 1 20); do
  [ "$DRY_RUN" = 1 ] && break
  remain="$(list_tuis)"
  [ -z "$remain" ] && { log "все TUI остановлены"; break; }
  sleep 1
done

# --- 7. Запускаем новый TUI через boot-скрипт с динамическим промптом ---
log "запуск нового TUI (boot-скрипт)..."
if [ "$DRY_RUN" = 1 ]; then
  log "DRY_RUN: было бы: TASK_PROMPT=<...> WORKDIR=$ROOT bash $BOOT"
  log "DRY_RUN завершён — ничего не изменено"
  exit 0
fi
TASK_PROMPT="$TASK_PROMPT" WORKDIR="$ROOT" bash "$BOOT" >>"$LOG" 2>&1
rc=$?
log "boot rc=$rc"
# --- 7b. Помечаем, что перезапуск выполнен (анти-цикл: 2-й раз будет отказ) ---
n=$(tr -dc '0-9' < "$COUNTER_FILE" 2>/dev/null); n=${n:-0}
echo $((n+1)) > "$COUNTER_FILE"
log "count -> $((n+1)) (дальнейшие self-restart будут отклонены)"
# --- 8. Короткое подтверждение, что новый TUI жив ---
sleep 5
if list_tuis | grep -q .; then
  log "НОВЫЙ TUI запущен: $(list_tuis | tr '\n' ' ')"
else
  log "ПРЕДУПРЕЖДЕНИЕ: новый TUI не найден в списке — проверь $LOG"
fi
exit $rc
