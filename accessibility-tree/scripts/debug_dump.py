#!/usr/bin/env python3
"""Отладка: выводим ВСЁ дерево без фильтров."""

import sys
import pyatspi


def dump_node(node, depth=0):
    if node is None or depth > 12:
        return
    try:
        role = node.get_role_name()
        name = node.get_name().strip()
        has_comp = False
        coords = ""
        try:
            comp = node.queryComponent()
            ext = comp.get_extents(pyatspi.XY_SCREEN)
            has_comp = True
            coords = f" [{ext.x},{ext.y} {ext.width}x{ext.height}]"
        except Exception:
            pass

        indent = "  " * depth
        print(f"{indent}[{role}] '{name}'{coords}")
    except Exception as e:
        return

    try:
        for i in range(node.get_child_count()):
            dump_node(node.get_child_at_index(i), depth + 1)
    except Exception:
        pass


def main():
    target = sys.argv[1] if len(sys.argv) > 1 else "konsole"

    registry = pyatspi.Registry
    desktop = registry.getDesktop(0)

    for i in range(desktop.get_child_count()):
        app = desktop.get_child_at_index(i)
        if app is None:
            continue
        name = app.get_name().strip()
        if target.lower() not in name.lower():
            continue
        print(f"=== APP: {name} ===")
        dump_node(app)


if __name__ == "__main__":
    main()
