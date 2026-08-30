#!/usr/bin/env bash
# paste_image_ai_from_clipboard.sh — background (в фоне): вставка картинки из буфера → задача из буфера → Esc → Enter
# Порядок: Shift+Insert (картинка) → задача_в_буфер.sh (фразу кладёт в буфер) → Shift+Insert (задача) → Esc → sleep → Enter
set -euo pipefail
S=$(cd "$(dirname "$0")" && pwd)

# Автозапуск в фоне: если нет флага __bg — запустить себя через setsid и выйти
if [[ "${1:-}" != "__bg" ]]; then
  if pgrep -f "paste_image_ai_from_clipboard.sh __bg" >/dev/null 2>&1; then
    echo "Уже в фоне"; exit 0
  fi
  setsid bash "$0" __bg >/dev/null 2>&1 </dev/null &
  echo "Запущено в фоне (PID $!)"; exit 0
fi

"$S/press_ins.sh"          # 1. вставить картинку из буфера
sleep 0.5
"$S/задача_в_буфер.sh"     # 2. задача в буфер (по умолчанию: найти кнопку копировать)
sleep 0.5
"$S/press_ins.sh"          # 3. вставить задачу из буфера
"$S/press_esc.sh"          # 4. Esc
sleep 2   # задержка после эскейпа
"$S/press_enter_vvod.sh"   # 5. Enter — отправить
"$S/spryatalsya.sh"         # 6. спрятаться
