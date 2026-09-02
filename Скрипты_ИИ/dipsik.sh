#!/bin/bash
# Запуск DipSeek в браузере по умолчанию (Google Chrome)
URL="https://chat.deepseek.com/"
google-chrome --start-maximized "$URL"

# Ждём загрузку и кликаем в поле чата
sleep 5
cd "$(dirname "$0")"
python3 click_xy.py 726 578 0.5
