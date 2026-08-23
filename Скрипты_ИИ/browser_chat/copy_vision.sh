#!/usr/bin/env bash
# ============================================================
# copy_vision.sh — копия ответа браузерного ИИ (DeepSeek и др.)
# АВТОКОПИИ НЕТ: скрипт не ищет кнопку сам. Оркестратор
# смотрит скриншот, находит кнопку Copy глазами и задаёт координаты.
#
# Использование:
#   copy_vision.sh shot              — окно на 0,0 + скролл вниз (к последнему
#                                       ответу) → скрин экрана → картинка
#                                       улетает оркестратору (следующий turno)
#   copy_vision.sh click X Y [out]   — клик в экранных X,Y → буфер → out
#                                       (по умолчанию /tmp/deepseek_answer.md)
# Пиксели скриншота = координаты мыши: Chrome стоит на 0,0.
# ============================================================
set -euo pipefail
cd "$(dirname "$0")" || exit 1

CMD="${1:-}"
case "$CMD" in shot|click) ;; *)
  echo "использование: $0 shot | click <X> <Y> [out]"; exit 2 ;;
esac

find_win() {
  local w cls WIN=""
  while read -r w; do
    cls=$({ xprop -id "$w" WM_CLASS 2>/dev/null || true; } \
      | sed 's/WM_CLASS(STRING) = //' | cut -d, -f1 | tr -d '"')
    [ "$cls" = "google-chrome" ] && WIN="$w"
  done < <(xdotool search --name "")
  echo "$WIN"
}

activate_chrome() {
  local a
  xdotool windowraise "$WIN" 2>/dev/null || true
  xdotool windowactivate --sync "$WIN" 2>/dev/null || true
  sleep 0.3
  a=$(xdotool getactivewindow 2>/dev/null || echo "")
  if [ "$a" != "$WIN" ]; then
    xdotool windowfocus "$WIN" 2>/dev/null || true; sleep 0.5
    a=$(xdotool getactivewindow 2>/dev/null || echo "")
  fi
  [ "$a" = "$WIN" ]
}

WIN="$(find_win)"
[ -n "$WIN" ] || { echo "ERR: окно Chrome не найдено — сначала full_cycle.sh"; exit 2; }

case "$CMD" in

shot)
  ./win_fix.sh 1920 1024 >/dev/null
  activate_chrome || { echo "FAIL: Chrome не активное окно"; exit 5; }
  # Скролл вниз: под последним ответом ряд иконок с Copy
  xdotool mousemove 960 400
  for i in $(seq 1 30); do xdotool click 5; sleep 0.08; done
  sleep 0.5

  SHOT=/tmp/ds_screen.png
  spectacle -b -f -n -o "$SHOT" || { echo "FAIL: spectacle не снял скрин"; exit 1; }
  echo "OK: скрин $SHOT — отправляю оркестратору (прилетит в следующем turno)"
  # foreground зависает (23.08) — паттерн show-image skill: setsid + KONPID, фон
  K=$(ps -eo pid,args | grep '[k]onsole' | awk '{print $1; exit}')
  setsid /home/voron/Документы/VB-ollama/Скрипты_ИИ/show_image.sh "$SHOT" "$K" \
    </dev/null >/tmp/show_image_out.txt 2>&1 &

  # Фокус обратно в Konsole: пользователь свободен, пока ИИ смотрит картинку
  ../focus_consolidate.sh 2>/dev/null || true
  ;;

click)
  X="${2:?ERR: нужен X}" Y="${3:?ERR: нужен Y}"; OUT="${4:-/tmp/deepseek_answer.md}"
  [[ "$X" =~ ^[0-9]+$ ]] && [[ "$Y" =~ ^[0-9]+$ ]] || { echo "ERR: X,Y должны быть числами (получено: $X,$Y)"; exit 2; }

  ./win_fix.sh 1920 1024 >/dev/null
  activate_chrome || { echo "FAIL: Chrome не активное окно перед кликом (активно: $(xdotool getactivewindow 2>/dev/null || echo '?'))"; exit 5; }

  # Буфер чистим ПЕРЕД кликом — stale-содержимое невозможно
  xclip -selection clipboard < /dev/null

  xdotool mousemove "$X" "$Y"; sleep 0.4; xdotool click 1

  # Polling: React-копирование может занять время; берём МАКСИМУМ буфера
  # за ~3.5s (фиксированный sleep 1.2 давал гонку: xclip читал до заполнения)
  BEST=""
  for i in $(seq 1 8); do
    sleep 0.35
    CUR="$(timeout 3 xclip -selection clipboard -o 2>/dev/null || true)"
    [ "${#CUR}" -gt "${#BEST}" ] && BEST="$CUR"
    [ "${#BEST}" -ge 50 ] && break
  done
  printf '%s' "$BEST" > "$OUT"
  SIZE=$(wc -c < "$OUT")

  if ! [ -s "$OUT" ]; then
    # show_image НЕ вызываем: он шлёт ESC/Ctrl+Shift+V в живое TUI оркестратора
    spectacle -b -f -n -o /tmp/ds_screen_fail.png || true
    echo "FAIL: буфер пуст — клик мимо. Скрин: /tmp/ds_screen_fail.png (далее: copy_vision.sh shot)"; exit 1
  fi
  # Не путь к скриншоту (весь буфер = один путь к картинке)
  if head -c 20 "$OUT" | grep -qE '^(/tmp|/home/[^/]+/)[^/]*\.(png|jpg|jpeg|webp)$'; then
    spectacle -b -f -n -o /tmp/ds_screen_fail.png || true
    echo "FAIL: в буфере путь к файлу, а не текст ($SIZE B). Скрин: /tmp/ds_screen_fail.png"; exit 1
  fi
  if [ "$SIZE" -lt 50 ]; then
    # Короткий ответ (число, «Привет!») — УСПЕХ. Скрин на проверку, без show_image.
    spectacle -b -f -n -o /tmp/ds_screen_short.png || true
    echo "OK-short: $SIZE B → $OUT | КОНТЕНТ: $(head -c 300 "$OUT")"
  else
    echo "OK: $SIZE байт → $OUT | КОНТЕНТ: $(head -c 300 "$OUT")"
  fi
  ../focus_consolidate.sh 2>/dev/null || true
  ;;

esac
