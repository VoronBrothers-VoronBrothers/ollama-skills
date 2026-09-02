#!/bin/bash
# зрение.sh — последовательность: ID → свернуть → скриншот → ID → развернуть → вставка (Shift+Insert) → Esc → Enter
S=/home/voron/Документы/VB-ollama/Скрипты_ИИ

echo "[1/8] ID окна:"
ID=$("$S/win_id.sh") || { echo "окно не найдено, стоп"; exit 1; }
echo "   ID = $ID"
sleep 1

echo "[2/8] Сворачивание:"
"$S/win_min.sh" "$ID"
sleep 1

echo "[3/8] Скриншот:"
OUT=$("$S/screenshot.sh") || { echo "скриншот не удался, стоп"; exit 1; }
echo "   $OUT"
sleep 1

echo "[4/8] ID окна (после сворачивания):"
ID2=$("$S/win_id.sh") || ID2=$ID
echo "   ID = $ID2"
sleep 1

echo "[5/8] Разворачивание:"
"$S/win_restore.sh" "$ID2"
sleep 1

echo "[6/8] Вставка (Shift+Insert):"
"$S/press_ins.sh" "$ID2"
sleep 2

echo "[7/8] Esc (однажды, ПОСЛЕ вставки):"
sleep 1
"$S/press_esc.sh" "$ID2"


echo "[8/8] Enter:"
"$S/press_enter.sh" "$ID2"
echo "зрение: готово ✅"
