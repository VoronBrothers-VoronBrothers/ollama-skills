# Wikipedia (ru.wikipedia.org)

## Поиск

Поисковая строка: `#searchInput`
Форма не имеет удобного селектора для submit-кнопки.

**Рабочий способ поиска:**
```json
// 1. Fill
{"name":"puppeteer_fill","arguments":{"selector":"#searchInput","value":"запрос"}}

// 2. Submit через evaluate (кнопка не имеет id)
{"name":"puppeteer_evaluate","arguments":{"script":"const f=document.querySelector('form[action*=search]')||document.forms[0];f.submit();'ok'"}}
```

Прямой переход на статью проще: `https://ru.wikipedia.org/wiki/Название`

## Парсинг статей

| Что | Селектор / JS |
|-----|---------------|
| Название статьи | `document.title` (формат «Тема — Википедия») |
| Заголовок h1 | `document.querySelector("h1")?.textContent` |
| Первый абзац | `document.querySelector(".mw-parser-text p")?.textContent` |
| Разделы (h2) | `Array.from(document.querySelectorAll("h2")).map(h=>h.textContent)` |
| Ссылки в статье | `Array.from(document.querySelector(".mw-parser-text").querySelectorAll("a")).slice(0,N).map(a=>({text:a.textContent,href:a.href}))` |

## Примечания

- На заглавной странице `.mw-parser-text p` пуст (нет прозы) — парсить только на страницах статей.
- URL с кириллицей — процент-энкодинг: `https://ru.wikipedia.org/wiki/Python_(%D1%8F%D0%B7%D1%8B%D0%BA_...)`
