#!/bin/bash
# simple_screenshot_v2.sh — шаг 1 зрения: сворачивает окно оркестратора → скриншот (все флаги) → разворачивает окно → путь в буфер → проверка буфера
set -uo pipefail
export DISPLAY="${DISPLAY:-:0}"

# 1. Сворачиваю себя (окно оркестратора)
id=$(xdotool search --name '~ : ollama' 2>/dev/null | head -n1 || true)
[ -n "$id" ] || { echo "окно оркестратора не найдено" >&2; exit 1; }
xdotool windowminimize "$id"
sleep 1

# 2. Скриншот со всеми флагами: фон + весь экран + без уведомления + в файл
FILE="/tmp/screenshot_$(date +%Y%m%d_%H%M%S)_$$${RANDOM}.png"
spectacle -b -f -n -o "$FILE" || { echo "ошибка: скриншот не получен" >&2; exit 1; }

# 3. Разворачиваю себя
sleep 1
xdotool windowactivate "$id" 2>/dev/null || true

# 4. Путь к картинке в буфер (clipboard)
printf '%s' "$FILE" | xclip -selection clipboard > /dev/null 2>&1 &

# 5. Проверка буфера: читаем обратно, путь должен совпасть и файл существовать
TEXT=""
for i in 1 2 3; do
    TEXT="$(xclip -selection clipboard -o)"
    [ "$TEXT" = "$FILE" ] && break
    sleep 0.3
done

if [ "$TEXT" != "$FILE" ] || [ ! -f "$TEXT" ]; then
    echo "ошибка: буфер не совпал или файла нет: '$TEXT'" >&2
    exit 1
fi

echo "готово: $FILE"
