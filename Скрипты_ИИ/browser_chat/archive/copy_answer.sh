#!/usr/bin/env bash
# copy_answer.sh [X] [Y|auto] [out_file]   |   copy_answer.sh [out_file]
# Клик по copy-иконке DeepSeek → буфер → файл. Координаты нативные (1920x1080).
# Y=auto (дефолт): автодетект ряда иконок последнего ответа (detect_copy_row.py).
# Буфер чистится ПЕРЕД кликом — старое содержимое невозможно.
set -euo pipefail

cd "$(dirname "$0")" || exit 1

# Разбор аргументов: числовое X → [X] [Y|auto] [out]; иначе единый аргумент = out_file.
if [[ "${1:-}" =~ ^[0-9]+$ ]]; then
  X="$1"; Y="${2:-auto}"; OUT="${3:-/tmp/deepseek_answer.md}"
elif [ -n "${1:-}" ]; then
  [[ -z "${2:-}" ]] || { echo "ERR: после non-numeric первого аргумента (out_file) второго не ожидается"; exit 2; }
  X=723; Y=auto; OUT="$1"
else
  X=723; Y=auto; OUT="/tmp/deepseek_answer.md"
fi
[[ "$X" =~ ^[0-9]+$ ]] || { echo "ERR: X должно быть числом (получено: $X)"; exit 2; }
WIN=""
while read -r w; do
  cls=$({ xprop -id "$w" WM_CLASS 2>/dev/null || true; } | sed 's/WM_CLASS(STRING) = //' | cut -d, -f1 | tr -d '"')
  [ "$cls" = "google-chrome" ] && WIN=$w
done < <(xdotool search --name "")
[ -z "$WIN" ] && { echo "ERR: окно Chrome не найдено"; exit 2; }

./win_fix.sh 1920 1024 >/dev/null || exit 3
xdotool windowactivate --sync "$WIN"; sleep 0.8

# Надёжный фокус перед кликом: Chrome ДОЛЖЕН быть активным окном,
# иначе клик уйдёт в окно-поверхность (напр., консоль оркестратора).
activate_chrome() {
  xdotool windowraise "$WIN" 2>/dev/null || true
  xdotool windowactivate --sync "$WIN" 2>/dev/null || true
  sleep 0.3
  local a; a=$(xdotool getactivewindow 2>/dev/null || echo "")
  if [ "$a" != "$WIN" ]; then
    xdotool windowfocus "$WIN" 2>/dev/null || true; sleep 0.5
    a=$(xdotool getactivewindow 2>/dev/null || echo "")
  fi
  [ "$a" = "$WIN" ]
}

# Автодетект Y ряда иконок (если не задан явно)
if [ "$Y" = "auto" ]; then
  Y=$(./detect_copy_row.py 2>/dev/null) || { echo "FAIL: автодетект ряда иконок не сработал — укажи Y вручную"; exit 4; }
  echo "детект: Y=$Y"
fi

# Очистка буфера: гарантируем пустой буфер
xclip -selection clipboard < /dev/null

# Финальная проверка фокуса (автодетект Y мог занять время — фокус могли украсть)
activate_chrome || {
  echo "FAIL: Chrome не активное окно перед кликом (активно: $(xdotool getactivewindow 2>/dev/null || echo '?')) — клик бы ушёл мимо"
  exit 5
}

# Клик по copy-иконке
xdotool mousemove "$X" "$Y"; sleep 0.4; xdotool click 1
sleep 1.5

# Чтение буфера → файл (с проверкой ошибок; timeout от висящего stale-owner'а)
if ! timeout 5 xclip -selection clipboard -o > "$OUT"; then
  echo "FAIL: не удалось прочитать буфер (timeout или нет владельца)"
  exit 1
fi
SIZE=$(wc -c < "$OUT")

if [ "$SIZE" -lt 50 ]; then
  echo "FAIL: буфер слишком мал ($SIZE байт) — координаты вероятно неверны"
  exit 1
fi

# Проверка: не путь к скриншоту (строго: путь к картинке, весь буфер = один путь)
if head -c 20 "$OUT" | grep -qE '^(/tmp|/home/[^/]+/)[^/]*\.(png|jpg|jpeg|webp)$'; then
  echo "FAIL: в буфере путь к файлу, а не текст ($SIZE байт)"
  exit 1
fi

echo "OK: $SIZE байт → $OUT"

# Сигнал пользователю «ИИ закончил»: вернуть фокус в Konsole
../focus_consolidate.sh 2>/dev/null || true
