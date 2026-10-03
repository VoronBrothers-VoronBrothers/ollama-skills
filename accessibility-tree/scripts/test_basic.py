#!/usr/bin/env python3
"""Тест: можно ли прочитать дерево AT-SPI."""

import pyatspi


def main():
    try:
        registry = pyatspi.Registry
        desktop = registry.getDesktop(0)
        count = desktop.get_child_count()
        print(f"OK! Найдено окон/приложений: {count}")

        for i in range(count):
            app = desktop.get_child_at_index(i)
            if app is None:
                continue
            name = app.get_name().strip()
            children = app.get_child_count()
            if name:
                print(f"  [{i}] {name} (детей: {children})")

    except Exception as e:
        print(f"ОШИБКА: {e}")


if __name__ == "__main__":
    main()
