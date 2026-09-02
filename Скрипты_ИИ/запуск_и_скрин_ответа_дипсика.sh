#!/usr/bin/env bash
# скрин_ответа_дипсика.sh — последовательность: спрятаться → дипсик → тестовый ввод → Enter → скриншот → ку-ку
set -euo pipefail
S=$(cd "$(dirname "$0")" && pwd)

echo "[1/6] Я спрятался:"
"$S/spryatalsya.sh"

echo "[2/6] DeepSeek:"
"$S/dipsik.sh" &
DPID=$!
sleep 4   # загрузка Chrome + клик в поле чата (в dipsik.sh)

echo "[3/6] Тестовый ввод: Привет"
"$S/type_text.sh" 'Привет' &   # внутри пауза 3 сек на переключение
TPID=$!
wait "$TPID"

echo "[4/6] Ввод (Enter):"
"$S/press_enter.sh"
sleep 8

echo "[5/6] Скриншот:"
"$S/screenshot.sh"

echo "[6/6] Ку-ку (покажись):"
"$S/ку-ку.sh"
