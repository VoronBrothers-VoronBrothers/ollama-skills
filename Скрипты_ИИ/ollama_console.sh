#!/usr/bin/env bash
# Открывает консоль (konsole), запускает `ollama` (TUI), выбирает модель
# (стрелка вправо → ввод имени → Enter), затем /think (Enter, Down×2, Enter),
# Shift+Tab (полный доступ) и вводит задание.
# ВАЖНО: ищем НОВОЕ окно (дифф "до/после" запуска), а не первое окно с классом
# konsole — иначе при запуске из уже открытой konsole ввод улетит в старое окно.
set -euo pipefail

# --- Окружение: при старте сессии DISPLAY/XAUTHORITY могут ещё не успеть
# --- экспортироваться в user-менеджера (гонка с graphical-session.target) ---
export DISPLAY="${DISPLAY:-:0}"
if [ -z "${XAUTHORITY:-}" ]; then
  XA="$(ls -t /run/user/"${UID}"/xauth_* 2>/dev/null | head -n1 || true)"
  if [ -n "$XA" ]; then export XAUTHORITY="$XA"; fi
fi
# Ждём, пока X-сервер примет подключения (до 60 с)
ok=0
for i in $(seq 1 60); do
  if xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then ok=1; break; fi
  sleep 1
done
if [ "$ok" -ne 1 ]; then echo "X-сервер ($DISPLAY) недоступен" >&2; exit 1; fi

CMD="ollama"

# --- Динамика для самовозобновления (назад-совместимо) ---
# WORKDIR: каталог, откуда запускается TUI (туда же пишет /save). По умолчанию корень проекта.
WORKDIR="${WORKDIR:-/home/voron/Документы/VB-ollama}"
# TASK_PROMPT: текст задания, который вводится в TUI. По умолчанию — стартовый промт.
TASK_PROMPT="${TASK_PROMPT:-выполни инструкции которые лежат /home/voron/Документы/VB-ollama/Папка заданий для AI/}"

# 0. Снимаем список уже существующих окон konsole ДО запуска
BEFORE="$(xdotool search --class konsole 2>/dev/null || true)"

# 1. Открываем консоль (konsole) в отдельном процессе
konsole --hold --nofork &
TPID=$!

# 2. Ждём, пока появится НОВОЕ окно (того, которого не было в BEFORE)
WIN=""
for i in $(seq 1 60); do
  NOW="$(xdotool search --class konsole 2>/dev/null || true)"
  for w in $NOW; do
    if ! grep -Fxq "$w" <<<"$BEFORE"; then
      WIN="$w"
      break
    fi
  done
  [ -n "$WIN" ] && break
  sleep 0.5
done
[ -n "$WIN" ] || { echo "Новое окно konsole не найдено" >&2; exit 1; }

# Даём терминалу время на инициализацию шелла
sleep 3

# Активируем окно (ставим фокус)
xdotool windowactivate --sync "$WIN" 2>/dev/null || true
sleep 1

# 3. Вводим команду: cd в рабочий каталог + ollama (чтобы /save писал в известный каталог)
xdotool type --window "$WIN" --delay 80 "cd $WORKDIR && $CMD"
sleep 1

# 4. Enter (выполняем команду)
xdotool key --window "$WIN" Return

# 5. Ждём, пока TUI поднимется и будет готов принимать ввод
sleep 3

# 6. Стрелка вправо — открываем меню выбора моделей
xdotool key --window "$WIN" Right
sleep 1

# 7. Вводим имя модели
xdotool type --window "$WIN" --delay 80 "qwen3.8-orchestrator"
sleep 1

# 8. Enter (выбираем модель)
xdotool key --window "$WIN" Return
sleep 2

# 9. Вводим /think
xdotool type --window "$WIN" --delay 80 "/think"
sleep 1

# 10. Enter (подтверждаем /think)
xdotool key --window "$WIN" Return
sleep 1

# 11. Стрелка вниз
xdotool key --window "$WIN" Down
sleep 0.5

# 12. Ещё стрелка вниз
xdotool key --window "$WIN" Down
sleep 0.5

# 13. Enter (выбираем пункт) low thinking (режим обдумывания сокращённый)
xdotool key --window "$WIN" Return
sleep 1

# 14. Shift+Tab — предоставление полного доступа
xdotool key --window "$WIN" shift+Tab
sleep 1

# 15. Вводим текст задания (TASK_PROMPT задан выше; можно переопределить через env)
xdotool type --window "$WIN" --delay 80 "$TASK_PROMPT"
sleep 1

# 16. Enter (отправляем)
xdotool key --window "$WIN" Return
sleep 1

echo "Готово: konsole PID=$TPID, окно=$WIN"
