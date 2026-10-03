---
name: blender-mcp
description: "Работа в программе blender" 
---
# Blender MCP — управление Блендером через MCP-сервер

## Предусловие
1. В Блендере установлен аддон **MCP for Blender** (Preferences → Add-ons)
2. Аддон запущен: N-панель в 3D-вьюпорте → вкладка "MCP for Blender" → "Connected on port 8976"
3. Supergateway поднят на порту **8816**:
   ```bash
   tmux new-session -d -s mcp-blender -x 200 -y 50
   tmux send-keys -t mcp-blender \
     "npx -y supergateway --stdio \"~/.local/bin/uvx mcp-for-blender\" --port 8816 --cors --outputTransport streamableHttp" \
     Enter
   ```

## Команда (основной способ)

```bash
python3 ~/.ollama/skills/blender-mcp/scripts/blender_cmd.py "ВАШ_КОД"
```

Примеры:
```bash
# Сколько объектов в сцене
python3 ~/.ollama/skills/blender-mcp/scripts/blender_cmd.py "import bpy; print(len(bpy.data.objects))"

# Создать куб
python3 ~/.ollama/skills/blender-mcp/scripts/blender_cmd.py "import bpy; bpy.ops.mesh.primitive_cube_add(location=(1,2,0)); print('куб создан')"

# Рендер в файл
python3 ~/.ollama/skills/blender-mcp/scripts/blender_cmd.py "import bpy; bpy.context.scene.render.filepath='/tmp/view.png'; bpy.ops.render.render(write_still=True); print('ок')"
```

## Проверка что связь жива

```bash
python3 ~/.ollama/skills/blender-mcp/scripts/blender_cmd.py "print('ping ok')"
# Ожидается: ping ok
```

Если `Connection refused` — проверь:
- Блендер запущен? Аддон включён? (N-панель → MCP for Blender → Connected?)
- Supergateway работает? `ss -tlnp | grep 8816`

## Инструменты MCP (доступны через blender_cmd.py)

| Инструмент | Зачем |
|---|---|
| `execute_blender_code` | Выполнить python-код в Блендере (основной) |
| `get_scene_info` | Инфо о сцене: объекты, материалы, рендер-настройки |
| `get_object_info` | Детали конкретного объекта |
| `get_viewport_screenshot` | Скриншот вьюпорта из Блендера |

## Рендер + просмотр

```bash
# 1. Отрендерить
python3 ~/.ollama/skills/blender-mcp/scripts/blender_cmd.py "import bpy; bpy.context.scene.render.filepath='/tmp/view.png'; bpy.ops.render.render(write_still=True); print('ok')"

# 2. Посмотреть (через vision скилл)
python3 ~/.ollama/skills/vision-api/scripts/ask.py /tmp/view.png "Что в сцене?"
```

## Важные правила для Blender 5.2

- `nodes['Principled BSDF']` НЕ работает (русский Блендер) → используй: `next(n for n in nodes if n.type == 'BSDF_PRINCIPLED')`
- Цвет элемента ColorRamp: `.color = (r,g,b,a)` а не `.colors[3:]`
- `bmesh.ops.create_icosphere`: параметр `cap_ends` удалён в 5.2 — НЕ использовать
- Для сложных фигур предпочитай **модификаторы** (Array, Curve) вместо ручного bmesh — надёжнее и быстрее

## Остановка supergateway

```bash
tmux kill-session -t mcp-blender
# или
pkill -f "supergateway.*8816"
```
