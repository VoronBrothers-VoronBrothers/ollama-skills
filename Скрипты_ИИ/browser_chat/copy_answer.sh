#!/usr/bin/env bash
# copy_answer.sh [X] [Y|auto] [out_file]
# Клик по copy-иконке DeepSeek → буфер → файл. Координаты нативные (1920x1080).
# Y=auto (дефолт): автодетект ряда иконок последнего ответа (detect_copy_row.py).
# Буфер чистится ПЕРЕД кликом — старое содержимое невозможно.
set -u
X="${1:-723}"
Y="${2:-auto}"
OUT="${3:-/tmp/deepseek_answer.md}"

cd "$(dirname "$0")" || exit 1
WIN=$(xdotool search --name "DeepSeek" 2>/dev/null | head -1)
[ -z "$WIN" ] && { echo "ERR: окно DeepSeek не найдено"; exit 2; }

./win_fix.sh 1920 1024 >/dev/null || exit 3
xdotool windowactivate --sync "$WIN"; sleep 0.8

# Автодетект Y ряда иконок (если не задан явно)
if [ "$Y" = "auto" ]; then
  Y=$(./detect_copy_row.py 2>/dev/null) || { echo "FAIL: автодетект ряда иконок не сработал — укажи Y вручную"; exit 4; }
  echo "детект: Y=$Y"
fi

# Очистка буфера, чтобы старый текст не прошёл за ответ
printf '' | xclip -selection clipboard

# Клик по copy-иконке
xdotool mousemove "$X" "$Y"; sleep 0.4; xdotool click 1
sleep 1.5

# Чтение буфера → файл
xclip -selection clipboard -o 2>/dev/null > "$OUT" || { echo "FAIL: не удалось прочитать буфер"; exit 1; }
SIZE=$(wc -c < "$OUT")

if [ "$SIZE" -lt 50 ]; then
  echo "FAIL: буфер слишком мал ($SIZE байт) — координаты вероятно неверны"
  exit 1
fi

# Проверка: не путь к скриншоту
if head -c 20 "$OUT" | grep -qE '^/tmp|^/home.*\.png'; then
  echo "FAIL: в буфере путь к файлу, а не текст ($SIZE байт)"
  exit 1
fi

echo "OK: $SIZE байт → $OUT"

# Сигнал пользователю «ИИ закончил»: вернуть фокус в Konsole
../focus_consolidate.sh 2>/dev/null || true
