---
name: accessibility-tree
description: Получить дерево доступности GUI (AT-SPI) с точными координатами элементов для кликов и ввода. Использовать когда нужно взаимодействовать с интерфейсом (нажать кнопку, вставить каретку, ввести текст), а не просто посмотреть на экран.
---

# Дерево доступности для точного управления GUI

Скрипт `scripts/scan.py` читает системное дерево AT-SPI через pyatspi и возвращает JSON с интерактивными элементами и их экранными координатами.

## Когда использовать

- Нужно кликнуть по конкретной кнопке/элементу → **здесь**
- Нужно вставить каретку в поле ввода → **здесь**
- Нужно понять структуру активного окна → **здесь**
- Нужно просто «посмотреть что на экране» → selfshot / vision-api

## Запуск

```bash
# Всё дерево (все приложения):
python3 ~/.ollama/skills/accessibility-tree/scripts/scan.py

# Только конкретное приложение:
python3 ~/.ollama/skills/accessibility-tree/scripts/scan.py --app "dolphin"

# Найти элемент по имени (частичный match, без учёта регистра):
python3 ~/.ollama/skills/accessibility-tree/scripts/scan.py --app "konsole" --name "правка"

# Только определённый тип элементов:
python3 ~/.ollama/skills/accessibility-tree/scripts/scan.py --role "push button"

# Комбинация фильтров:
python3 ~/.ollama/skills/accessibility-tree/scripts/scan.py --app "chrome" --name "войти" --role "push button"
```

## Формат вывода (JSON)

```json
[
  {
    "app": "dolphin",
    "elements": [
      {
        "id": 1,
        "role": "push button",
        "name": "Применить",
        "x": 450,
        "y": 620,
        "w": 120,
        "h": 40,
        "center_x": 510,
        "center_y": 640
      }
    ]
  }
]
```

- `center_x`, `center_y` — точка для клика (геометрический центр элемента)
- Координаты абсолютные, экранные (X11), от левого верхнего угла монитора

## Как использовать координаты

После получения JSON:
1. Найти нужный элемент по `name` и/или `role`
2. Взять `center_x` и `center_y`
3. Вызвать скилл **mouse-click** с этими координатами

## Фильтры ролей (что возвращается)

- `push button` — кнопки
- `text` / `entry` — поля ввода
- `check box` — чекбоксы
- `toggle button` — переключатели
- `menu item` — пункты меню
- `combo box` — выпадающие списки
- `link` — ссылки (в браузере)
- `list item` — элементы списка
- `page tab` — вкладки
- `radio button`, `slider`, `spin button`

## Ограничения

| Ситуация | Что делать |
|----------|-----------|
| Браузер не отдаёт DOM | Запустить Chrome с `--force-render-accessibility` |
| Элемент не найден в дереве | Fallback: Accerciser (`accerciser`) для полного дерева → selfshot --full-grid |
| Electron-приложение пустое | Проверить, может нужно `--force-render-accessibility` |
| Окно свернуто | Нет в STATE_SHOWING — сначала развернуть окно |
| LibreOffice кастомные диалоги (расширения) не отдают push button | Клик по координатам из selfshot --full-grid; либо UNO-скрипт |

## Известные имена приложений в AT-SPI

| Приложение | Имя в `--app` |
|------------|---------------|
| LibreOffice (Writer/Calc) | `soffice.bin` |
| Chrome | `chrome` |
| Konsole (терминал KDE) | `konsole` |
| Dolphin (файловый менеджер) | `dolphin` |

> Если имя не найдено — запусти `scan.py` без `--app`, посмотри список в выводе.

## Требования

- `python3-pyatspi` установлен (`sudo apt install python3-pyatspi`)
- X11 сессия (не Wayland)
- `QT_ACCESSIBILITY=1` в окружении (уже стоит по умолчанию)
