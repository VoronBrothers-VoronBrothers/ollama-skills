---
name: blender-remote
description: Управление Блендером через локальный сокет-сервер.
---


## Предусловие
Блендер запущен, и в нём работает server.py (вставлен в Text Editor → Run Script).
Сервер слушает на `127.0.0.1:8989`.

## Команда

```bash
python3 ~/.ollama/skills/blender-remote/scripts/client.py "ВАШ_КОД"
```

Примеры:
```bash
# Получить имя сцены
python3 ~/.ollama/skills/blender-remote/scripts/client.py "bpy.context.scene.name"

# Создать куб
python3 ~/.ollama/skills/blender-remote/scripts/client.py "import bpy; bpy.ops.mesh.primitive_cube_add(location=(1,2,0)); 'done'"

# Рендер в файл
python3 ~/.ollama/skills/blender-remote/scripts/client.py "bpy.context.scene.render.filepath='/tmp/view.png'; bpy.ops.render.render(write_still=True); 'rendered'"
```

## Проверка что сервер жив

```bash
python3 ~/.ollama/skills/blender-remote/scripts/client.py "1+1"
# Ожидается: OK: 2
```

Если соединение отказано — Блендер не запущен или server.py не работает.

## Рендер + просмотр

```bash
# 1. Отрендерить
python3 ~/.ollama/skills/blender-remote/scripts/client.py "bpy.context.scene.render.filepath='/tmp/blender_view.png'; bpy.ops.render.render(write_still=True); 'ok'"

# 2. Посмотреть (через vision скилл)
python3 ~/.ollama/skills/vision/scripts/ask.py /tmp/blender_view.png "Что в сцене?"
```

## Правила
- Код выполняется через `eval` — это произвольный пайтон внутри Блендера.
- Ошибки возвращаются как `ERR: <сообщение>`. Читай и исправляй.
- Для многострочного кода используй `;` между выражениями или `\n`.
- Сервер живёт, пока открыт Блендер. Закрыл Блендер — сервер мёртв.
