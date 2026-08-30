#!/usr/bin/env bash
# chat_deepseek.sh — чат с DeepSeek
# Использование: ./chat_deepseek.sh "вопрос"   (по умолчанию "Привет")
# Логика:
#   1. foreground — start_and_screenshot_deepseek.sh: спрятаться → дипсик → ввод запроса (type_text) → Enter → скриншот → ку-ку
#   2. background — paste_image_ai_from_clipboard.sh: Shift+Insert (вставка изображения из буфера) → Esc → Enter
set -euo pipefail
S=$(cd "$(dirname "$0")" && pwd)

QUERY="${1:-Привет}"

echo "[1] Запрос: $QUERY (foreground: start_and_screenshot_deepseek)"
bash "$S/start_and_screenshot_deepseek.sh" "$QUERY"

echo "[2] Фоновая вставка изображения из буфера: paste_image_ai_from_clipboard"
nohup bash "$S/paste_image_ai_from_clipboard_and_a_goal.sh" > /tmp/deepseek_paste.log 2>&1 & disown
echo "chat_deepseek: фоновая вставка запущена (PID $!)"
