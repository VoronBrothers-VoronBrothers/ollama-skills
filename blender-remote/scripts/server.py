"""
Blender Remote Server — вставить в Text Editor Блендера и нажать Run Script.
Слушает на 127.0.0.1:8989, выполняет пайтон-код, возвращает результат.

ЗАЩИТЫ:
- try/except вокруг exec — ловит любые Python-ошибки
- Запрет bpy.ops (кроме render.render) — сегфолт в потоке
- Ограничение размера кода
"""

import socket
import threading
import ast
import re
import bpy


MAX_CODE_SIZE = 10240  # 10 KB


def is_safe(code):
    """Проверка что код не содержит опасных вызовов."""
    if len(code) > MAX_CODE_SIZE:
        return f"ERR: code too large ({len(code)} bytes, max {MAX_CODE_SIZE})"

    try:
        compile(code, '<remote>', 'exec')
    except SyntaxError as e:
        return f"ERR: syntax error: {e}"

    # Ищем bpy.ops.X.Y через regex — проще и надёжнее AST
    ops_calls = re.findall(r'bpy\.ops\.(.+?)(?=\s|\(|$)', code)
    for op in ops_calls:
        allowed = {'render.render', 'wm.save_as_mainfile'}
        if op not in allowed:
            return f"ERR: bpy.ops.{op} запрещён (крашит в потоке)"

    return None


def handle(conn):
    try:
        data = b""
        while True:
            chunk = conn.recv(4096)
            if not chunk:
                break
            data += chunk

        code = data.decode("utf-8").strip()
        if not code:
            conn.sendall(b"ERR: empty command\n")
            return

        # Валидация на сервере (двойная защита)
        error = is_safe(code)
        if error:
            conn.sendall(error.encode("utf-8"))
            return

        try:
            if "\n" in code or ";" in code:
                _ns = {"bpy": bpy, "__builtins__": __builtins__}
                exec(compile(code, '<remote>', 'exec'), _ns)
                conn.sendall(b"OK:\n")
            else:
                result = eval(code, {"bpy": bpy, "__builtins__": __builtins__})
                msg = f"OK: {result}\n" if result is not None else "OK:\n"
                conn.sendall(msg.encode("utf-8"))
        except Exception as e:
            conn.sendall(f"ERR: {type(e).__name__}: {e}\n".encode("utf-8"))
    finally:
        conn.close()


def start():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(("127.0.0.1", 8989))
    s.listen(5)
    print("[blender-remote] Server ready on 127.0.0.1:8989")

    while True:
        conn, _ = s.accept()
        threading.Thread(target=handle, args=(conn,), daemon=True).start()


threading.Thread(target=start, daemon=True).start()
print("[blender-remote] Started in background.")
