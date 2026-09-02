#!/usr/bin/env bash
# bg-run.sh — запускает любой скрипт в фоне, логи в /dev/null
# Использование: bg-run.sh <скрипт> [аргументы...]
# Пример:    bg-run.sh ./зрение.sh
set -euo pipefail

if [[ $# -lt 1 || ! -e "$1" ]]; then
  echo "Использование: bg-run.sh <скрипт> [аргументы...]" >&2
  exit 1
fi

SCRIPT="$1"; shift
DIR="$(dirname "$(readlink -f "$SCRIPT")")"

# полные пути, чтобы nohup не ронял из-за кириллицы в CWD
ABS="$(readlink -f "$SCRIPT")"

setsid bash -c "cd '$DIR' && exec '$ABS' $*" > /dev/null 2>&1 < /dev/null &
PID=$!
disown 2>/dev/null || true
echo "запущено в фоне: $(basename "$ABS") PID=$PID (логи: /dev/null)"
