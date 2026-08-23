#!/usr/bin/env bash
# full_cycle.sh <вопрос> [WAIT=12]
# Полный цикл: New chat → ввод → Enter → ожидание → scroll_capture → sessions/<ts>/
# Точный WM_CLASS = "google-chrome" (не -stable: это Prizrak-box/VPN).
set -euo pipefail
cd "$(dirname "$0")" || exit 1

Q=${1:-ping}
WAIT=${2:-12}

WIN=""
while read -r w; do
  cls=$({ xprop -id "$w" WM_CLASS 2>/dev/null || true; } | sed 's/WM_CLASS(STRING) = //' | cut -d, -f1 | tr -d '"')
  [ "$cls" = "google-chrome" ] && WIN=$w
done < <(xdotool search --name "")

if [ -z "$WIN" ]; then
  echo "браузер не запущен — стартую chrome…"
  setsid /usr/bin/google-chrome https://chat.deepseek.com/ >/dev/null 2>&1 &
  for _ in $(seq 1 20); do
    WIN=""
    while read -r w; do
      cls=$({ xprop -id "$w" WM_CLASS 2>/dev/null || true; } | sed 's/WM_CLASS(STRING) = //' | cut -d, -f1 | tr -d '"')
      [ "$cls" = "google-chrome" ] && WIN=$w
    done < <(xdotool search --name "")
    [ -n "$WIN" ] && break
    sleep 1
  done
fi
[ -n "$WIN" ] || { echo "браузер не найден даже после старта"; exit 1; }

# Детерминированный размер + фокус
xdotool windowactivate --sync "$WIN" windowmove "$WIN" 0 0 windowsize "$WIN" 1920 1024

# Ждём загрузки страницы: заголовок окна содержит "DeepSeek" (до 15s)
for _ in $(seq 1 15); do
  title=$(xdotool getwindowname "$WIN" 2>/dev/null || true)
  case "$title" in *DeepSeek*) break;; esac
  sleep 1
done
sleep 0.8

# New chat → поле ввода (Chrome обязан быть активным окном, иначе клик уйдёт в konsole)
xdotool windowactivate --sync "$WIN" || true
sleep 0.3
if [ "$(xdotool getactivewindow 2>/dev/null)" != "$WIN" ]; then
  xdotool windowfocus "$WIN"; sleep 0.5
fi
[ "$(xdotool getactivewindow 2>/dev/null)" = "$WIN" ] || { echo "FAIL: Chrome не активное окно перед кликом (активно: $(xdotool getactivewindow 2>/dev/null))"; exit 5; }
xdotool mousemove 93 213 click 1; sleep 1.2
xdotool mousemove 960 570 click 1; sleep 0.6

# Очистка + ввод + Enter
xdotool key ctrl+a Delete; sleep 0.3
xdotool type --delay 30 --clearmodifiers "$Q"
sleep 0.3
xdotool key Return

echo "отправлен: $Q (ожидание ${WAIT}s)"
sleep "$WAIT"

# Scroll-capture: серии скринов + full.png
DIR="sessions/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$DIR"
printf '%s\n' "$Q" > "$DIR/question.txt"
./scroll_capture.sh "$DIR" </dev/null 2>&1 || echo "внимание: scroll_capture завершился с ошибкой (см. выше)"
cat > "$DIR/meta.json" <<JSON
{"question": "$Q", "timestamp": "$(date -I)", "wait": $WAIT}
JSON
echo "сессия: $DIR/"

# Поднять Konsole на передний план — сигнал пользователю «ИИ закончил»
../focus_consolidate.sh 2>/dev/null || true
