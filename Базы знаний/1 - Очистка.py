import json
import html  # <-- ДОБАВИЛИ ИМПОРТ
import re

# Регулярное выражение для удаления любых HTML-тегов
CLEANR = re.compile(r'<[^>]+>')

# Имена ваших файлов (замените на свои пути при необходимости)
input_json_file = "МоиДействия.json"
output_text_file = "cleaned_output.md"

print("Начало обработки файла...")

with open(input_json_file, "r", encoding="utf-8") as infile, \
     open(output_text_file, "w", encoding="utf-8") as outfile:
    
    # Загружаем массив объектов целиком 
    data = json.load(infile)
    
    for item in data:
        # Извлекаем список safeHtmlItem, если он есть в объекте
        html_items = item.get("safeHtmlItem", [])
        
        for html_obj in html_items:
            # Достаем сырой HTML-текст
            raw_html = html_obj.get("html", "")
            if not raw_html:
                continue
            
            # 1. Удаляем HTML-теги
            cleaned_text = re.sub(CLEANR, '', raw_html)
            
            # 2. Декодируем HTML-сущности (&quot; -> ", &amp; -> &)
            fixed_text = html.unescape(cleaned_text)  # <-- ДОБАВИЛИ ОЧИСТКУ СИМВОЛОВ
            
            # Записываем полностью очищенный текст в файл
            outfile.write(fixed_text + "\n\n---\n\n")  # <-- ИЗМЕНИЛИ ПЕРЕМЕННУЮ НА fixed_text

print(f"Готово! Очищенный текст сохранен в файл: {output_text_file}")
