#!/usr/bin/env bash
# tmux-ollama.sh — создаёт tmux-сессию (имя как у оркестратора) и запускает в ней команду: ollama
set -euo pipefail

# 1) Определяем имя сессии «как у меня»:
#    - если скрипт запущен из tmux — берём имя текущей сессии;
#    - иначе ищем существующую оркестратор-сессию в tmux ls;
#    - иначе используем зашитое по умолчанию.
NAME=""
if [ -n "${TMUX:-}" ]; then
  NAME=$(tmux display-message -p '#{session_name}') || true
fi
[ -z "$NAME" ] && NAME=$(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep '^orchestrator' | head -n1) || true
[ -z "$NAME" ] && NAME="orchestrator-this-is-your-own-tmux-send-pictures-here-with-task"

# 2) Проверяем, существует ли уже сессия с таким именем.
#    Если да — выводим сообщение и тихо завершаемся.
if tmux has-session -t "$NAME" 2>/dev/null; then
  echo "Сессия '$NAME' уже запущена. Скрипт завершается."
  exit 0
fi

# 3) Создаём сессию.
tmux new-session -d -s "$NAME"

# 4) В ней запускаем команду дословно: ollama
tmux send-keys -t "$NAME" "ollama" Enter

echo "Сессия tmux: $NAME (базовое имя как у оркестратора)"
echo "В панели запущено: ollama — присоединяйся командой: tmux attach -t \"$NAME\""
