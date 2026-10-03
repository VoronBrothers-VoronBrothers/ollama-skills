#!/usr/bin/env python3
"""Сканер дерева доступности → JSON с координатами."""

import json
import sys
import pyatspi


# Роли, которые нас интересуют (интерактивные элементы)
INTERESTING_ROLES = {
    'push button', 'text', 'entry', 'check box', 'toggle button',
    'menu item', 'combo box', 'link', 'list item', 'radio button',
    'page tab', 'slider', 'spin button'
}

# Размеры экрана (для проверки что элемент на экране)
SCREEN_W = 1920
SCREEN_H = 1080

counter = [0]


def scan_node(node, depth=0, in_popup=False):
    """Рекурсивно обходит дерево и собирает интерактивные элементы."""
    results = []
    if node is None:
        return results

    # Если вошли в popup menu — всё внутри скрыто до клика, пропускаем
    try:
        role_check = node.get_role_name()
        if role_check == 'popup menu':
            in_popup = True
    except Exception:
        pass

    if in_popup:
        return results

    try:
        state_set = node.getStateSet()
        # Пропускаем невидимые
        if not state_set.contains(pyatspi.STATE_SHOWING):
            return results
    except Exception:
        pass

    try:
        role = node.get_role_name()
        name = node.get_name().strip()

        # Берём координаты
        comp = node.queryComponent()
        extents = comp.getExtents(pyatspi.XY_SCREEN)

        # Проверяем что элемент на экране (не popup-координаты, не 0,0)
        on_screen = (extents.x >= 0 and extents.y >= 0 and
                     extents.x + extents.width <= SCREEN_W and
                     extents.y + extents.height <= SCREEN_H and
                     extents.width > 5 and extents.height > 5 and
                     not (extents.x == 0 and extents.y == 0))

        # Показываем только интересные элементы с именем ИЛИ text без имени
        if role in INTERESTING_ROLES and on_screen and (name or role == 'text'):
            counter[0] += 1
            results.append({
                "id": counter[0],
                "role": role,
                "name": name,
                "x": extents.x,
                "y": extents.y,
                "w": extents.width,
                "h": extents.height,
                "center_x": extents.x + extents.width // 2,
                "center_y": extents.y + extents.height // 2,
            })
    except Exception:
        pass

    # Рекурсия в детей
    try:
        for i in range(node.get_child_count()):
            child = node.get_child_at_index(i)
            results.extend(scan_node(child, depth + 1, in_popup))
    except Exception:
        pass

    return results


def main():
    # Аргументы:
    #   --app "имя"      — фильтр по приложению
    #   --name "текст"   — фильтр по имени элемента (частичный, без учёта регистра)
    #   --role "роль"     — фильтр по роли
    target_app = None
    target_name = None
    target_role = None

    args = sys.argv[1:]
    i = 0
    while i < len(args):
        if args[i] == "--app" and i + 1 < len(args):
            target_app = args[i + 1].lower()
            i += 2
        elif args[i] == "--name" and i + 1 < len(args):
            target_name = args[i + 1].lower()
            i += 2
        elif args[i] == "--role" and i + 1 < len(args):
            target_role = args[i + 1].lower()
            i += 2
        else:
            i += 1

    registry = pyatspi.Registry
    desktop = registry.getDesktop(0)

    all_elements = []
    for i in range(desktop.get_child_count()):
        app = desktop.get_child_at_index(i)
        if app is None:
            continue
        app_name = app.get_name().strip()

        # Фильтр по приложению
        if target_app and target_app not in app_name.lower():
            continue

        elements = scan_node(app)

        # Фильтр по имени элемента
        if target_name:
            elements = [e for e in elements if target_name in e["name"].lower()]

        # Фильтр по роли
        if target_role:
            elements = [e for e in elements if e["role"] == target_role]

        if elements:
            all_elements.append({
                "app": app_name,
                "elements": elements
            })

    print(json.dumps(all_elements, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
