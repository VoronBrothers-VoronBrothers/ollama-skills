#!/usr/bin/env bash
# Конвертация LoRA (safetensors) в GGUF. Результат кладётся рядом с исходным файлом.
# Запуск: ./convert_lora.sh /путь/adapter_model.safetensors
set -euo pipefail

LORA_FILE="${1:?Использование: $0 /путь/adapter_model.safetensors}"

[ -f "$LORA_FILE" ] || { echo "Файл не найден: $LORA_FILE"; exit 1; }

# Папка адаптера (скрипт llama.cpp требует папку, а не файл)
ADAPTER_DIR="$(dirname "$LORA_FILE")"

# Исходный safetensors → qwen3.8-27b-lora-f16.gguf в той же папке
BASENAME="$(basename "${LORA_FILE%.*}")"           # adapter_model
OUT_GGUF="$ADAPTER_DIR/${BASENAME}-f16.gguf"

# Путь до каталога скрипта (откуда брать конфиг базовой модели)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

LLAMA_CPP="/home/voron/Документы/VB-ollama/Git Clone-llama-and-others/llama.cpp-5060ti-sm120-cuda13"
PYTHON="$(dirname "$SCRIPT_DIR")/venv/bin/python"
# config.json базовой Qwen3.8-27B — иначе конвертер видит base_model_name_or_path
# из adapter_config.json (4-bit bnb) и падает: "Quant method bitsandbytes".
BASE_CONFIG="/home/voron/Документы/VB-ollama/Базы знаний/Цели-Проекты/#1 Дообучение ИИ/№2 Лора адаптер/base_config_27b"

echo "Адаптер:  $ADAPTER_DIR"
echo "Результат: $OUT_GGUF"
"$PYTHON" "$LLAMA_CPP/convert_lora_to_gguf.py" \
    "$ADAPTER_DIR" \
    --base "$BASE_CONFIG" \
    --outtype f16 \
    --outfile "$OUT_GGUF"
