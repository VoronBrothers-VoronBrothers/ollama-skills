#!/usr/bin/env bash
# full_cycle.sh <вопрос> [WAIT=12]
# Полный цикл: New chat → ввод → Enter → ожидание → scroll_capture → sessions/<ts>/
set -e
Q=${1:-ping}
WAIT=${2:-12}

WIN=""
for w in $(xdotool search --name ""); do
  cls=$(xprop -id "$w" WM_CLASS 2>/dev/null | sed 's/WM_CLASS(STRING) = //' | cut -d, -f1 | tr -d '"')
  [ "$cls" = "google-chrome" ] && WIN=$w
done
if [ -z "$WIN" ]; then
  echo "браузер не запущен — стартую chrome…"
  setsid /usr/bin/google-chrome https://chat.deepseek.com/ >/dev/null 2>&1 &
  for i in $(seq 1 20); do
    for w in $(xdotool search --name ""); do
      cls=$(xprop -id "$w" WM_CLASS 2>/dev/null | sed 's/WM_CLASS(STRING) = //' | cut -d, -f1 | tr -d '"')
      [ "$cls" = "google-chrome" ] && WIN=$w
    done
    [ -n "$WIN" ] && break
    sleep 1
  done
fi
[ -z "$WIN" ] && { echo "браузер не найден даже после старта"; exit 1; }
sleep 2  # дать странице загрузиться

# Детерминированный размер
xdotool windowactivate --sync $WIN windowmove $WIN 0 0 windowsize $WIN 1920 1024
sleep 0.5

# New chat → поле ввода
xdotool mousemove 93 213 click 1; sleep 1
xdotool windowactivate --sync $WIN; sleep 0.3
xdotool mousemove 960 570 click 1; sleep 0.4

# Очистка + ввод + Enter
xdotool key ctrl+a Delete; sleep 0.2
xdotool type --delay 30 --clearmodifiers "$Q"
sleep 0.3
xdotool key Return

echo "отправлен: $Q (ожидание ${WAIT}s)"
sleep "$WAIT"

# Scroll-capture: серии скринов + tall.png
DIR="sessions/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$DIR"
echo "$Q" > "$DIR/question.txt"
./scroll_capture.sh "$DIR" </dev/null 2>&1
cat > "$DIR/meta.json" <<JSON
{"question": "$Q", "timestamp": "$(date -I)", "wait": $WAIT}
JSON
echo "сессия: $DIR/"

# Поднять Konsole на передний план — сигнал пользователю «ИИ закончил»
../focus_consolidate.sh 2>/dev/null || true
