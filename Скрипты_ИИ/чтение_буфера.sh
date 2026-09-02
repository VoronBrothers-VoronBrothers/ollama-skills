#!/bin/bash

# 1. Читаем путь из буфера обмена
TARGET_PATH=$(xclip -selection clipboard -o | tr -d '\n\r')

# 2. Проверяем, существует ли такая папка или файл
if [ -d "$TARGET_PATH" ]; then
    echo "[Система]: Обнаружена директория $TARGET_PATH. Собираю структуру для ИИ..."
    
    # Генерируем контекст: список файлов + первые 10 строк текстовых файлов
    STRUCT=$(tree -L 2 "$TARGET_PATH" 2>/dev/null || ls -la "$TARGET_PATH")
    
    # 3. Передаем всё это вашему ИИ (замените команду ниже на вызов вашего локального ИИ)
    # Пример для CLI-версии вашего ИИ:
    echo -e "В буфере обмена сейчас путь к папке: $TARGET_PATH\n\nВот её структура:\n$STRUCT" | ollama run orchestrator

elif [ -f "$TARGET_PATH" ]; then
    echo "[Система]: Обнаружен файл $TARGET_PATH. Читаю содержимое..."
{ echo "В буфере обмена сейчас содержимое файла $TARGET_PATH:"; cat "$TARGET_PATH"; } | ollama run orchestrator
else
    # Если в буфере просто текст, а не путь к папке
    echo "В буфере обмена сейчас этот текст: $TARGET_PATH" | ollama run orchestrator
fi
