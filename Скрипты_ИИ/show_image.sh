#!/usr/bin/env bash
# ============================================================
# show_image.sh <картинка.png>
# Показывает картинку оркестратору: своё окно konsole (по
# PID-цепочке) → фокус → путь в буфер → ctrl+U → ESC →
# Ctrl+Shift+V (вставить) → Enter. Следующий ход — со скетчком.
# ============================================================
set -euo pipefail
export DISPLAY="${DISPLAY:-:0}"
if [ -z "${XAUTHORITY:-}" ]; then
  XA="$(ls -t /run/user/"${UID}"/xauth_* 2>/dev/null | head -n1 || true)"
  [ -n "$XA" ] && export XAUTHORITY="$XA"
fi

IMG="${1:?использование: show_image.sh <путь-к-картинке>}"
[ -f "$IMG" ] || { echo "ОШИБКА: нет файла $IMG" >&2; exit 1; }

# --- 1. Ищу своё konsole в PID-цепочке (bash→ollama→zsh→konsole) ---
KONPID="${2:-}"
if [ -z "$KONPID" ]; then
  pid=$$
  while [ "$pid" -gt 1 ]; do
    exe="$(readlink /proc/$pid/exe 2>/dev/null | xargs basename 2>/dev/null || true)"
    [ "$exe" = "konsole" ] && { KONPID="$pid"; break; }
    pid="$(awk '{print $4}' /proc/$pid/stat 2>/dev/null || echo 1)"
  done
fi
[ -n "$KONPID" ] || { echo "ОШИБКА: konsole не найден (pid=$$, arg=$2)" >&2; exit 1; }

WIN=""
for w in $(timeout 3 xdotool search --class konsole 2>/dev/null); do
  wp="$(timeout 2 xdotool getwindowpid "$w" 2>/dev/null || true)"
  [ "$wp" = "$KONPID" ] && { WIN="$w"; break; }
done
[ -n "$WIN" ] || { echo "ОШИБКА: окно konsole с pid $KONPID не найдено" >&2; exit 1; }

# --- 2. Фокус на моём окне (активным может быть другой терминал) ---
timeout 3 xdotool windowactivate "$WIN" 2>/dev/null || true

TEXT="картинка $(date +%Y-%m-%d) $IMG"
echo "$TEXT" > /tmp/show_image_last.txt

# --- 3. Текст в буфер обмена ---
printf '%s' "$TEXT" | timeout 5 xclip -selection clipboard

# --- 4. Снова фокус (на всякий случай) ---
sleep 2
timeout 3 xdotool windowactivate "$WIN" 2>/dev/null || true
sleep 2

# --- 5-8. ctrl+U (чистить строку) → ESC (пауза TUI) → Ctrl+Shift+V → Enter ---
timeout 3 xdotool key --window "$WIN" ctrl+u     2>/dev/null || true
sleep 2
timeout 3 xdotool key --window "$WIN" Escape     2>/dev/null || true
sleep 0.4
timeout 3 xdotool key --window "$WIN" ctrl+shift+v 2>/dev/null || true
sleep 0.5
timeout 3 xdotool key --window "$WIN" Return    2>/dev/null || true

echo "OK: win=$WIN konsole_pid=$KONPID текст=«$TEXT»"
