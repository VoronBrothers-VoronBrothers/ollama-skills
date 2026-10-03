#!/usr/bin/env python3
"""Клиент для blender-remote: валидирует код, шлёт в сокет, печатает ответ."""

import socket
import sys
import re


def validate(code):
    """Локальная проверка синтаксиса. Не гоняем мусор в Блендер."""
    try:
        compile(code, '<blender-remote>', 'exec')
    except SyntaxError as e:
        return f"ERR: syntax check failed locally: {e}"

    # Запрет bpy.ops из потока — сегфолт. Разрешён только bpy.ops.render.render
    ops_calls = re.findall(r'bpy\.ops\.(.+?)(?=\s|\(|$)', code)
    for op in ops_calls:
        if op != 'render.render':
            return (f"ERR: bpy.ops.{op} запрещён (крашит в потоке). "
                    f"Используй bmesh + bpy.data. Исключение: bpy.ops.render.render")

    # Защита от очень длинных скриптов (>10KB) — гоняй чанками
    if len(code) > 10240:
        return f"ERR: код слишком большой ({len(code)} байт). Разбей на части."

    return None


def main():
    if len(sys.argv) < 2:
        print("Usage: client.py 'python_expression'")
        sys.exit(1)

    code = " ".join(sys.argv[1:])

    # 1. Валидация ДО отправки
    error = validate(code)
    if error:
        print(error)
        sys.exit(1)

    # 2. Отправка
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(60)
        s.connect(("127.0.0.1", 8989))
        s.sendall(code.encode("utf-8"))
        s.shutdown(socket.SHUT_WR)

        chunks = []
        while True:
            data = s.recv(4096)
            if not data:
                break
            chunks.append(data)
        s.close()

        print(b"".join(chunks).decode("utf-8").strip())

    except ConnectionRefusedError:
        print("ERR: connection refused — Блендер не запущен или server.py не работает")
        sys.exit(1)
    except socket.timeout:
        print("ERR: timeout — сервер не ответил за 60 секунд (Блендер мог зависнуть)")
        sys.exit(1)


if __name__ == "__main__":
    main()
