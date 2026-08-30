import json  # Не забудьте импортировать в начале файла

with open("cleaned_output.txt", "r", encoding="utf-8") as f:
    # Делим файл по вашей границе
    chunks = f.read().split("========================================")

# Убираем пустые чанки и лишние пробелы
chunks = [chunk.strip() for chunk in chunks if chunk.strip()]

print(f"Получено {len(chunks)} готовых документов для базы знаний.")

# --- ДОПИСЫВАЕМ СЮДА ---
# Сохраняем список строк в файл chunks.json
output_json_file = "chunks.json"

with open(output_json_file, "w", encoding="utf-8") as json_file:
    # indent=4 сделает файл визуально красивым и читаемым человеком
    # ensure_ascii=False сохранит русский текст понятными буквами, а не \u0430
    json.dump(chunks, json_file, ensure_ascii=False, indent=4)

print(f"Все чанки успешно сохранены в файл {output_json_file}!")
