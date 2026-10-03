#!/usr/bin/env python3
"""Отправка кода в Blender по сокету. Принимает код из файла или stdin.

Использование:
  python3 blender_send.py /tmp/my_code.py
  echo 'import bpy' | python3 blender_send.py --stdin
"""
import socket, sys, ast, re

def validate(code):
    # Syntax check
    try:
        tree = ast.parse(code)
    except SyntaxError as e:
        print(f"SYNTAX ERROR: {e}")
        return False
    # Block bpy.ops (кроме render.render и scene.save_as_mainfile)
    allowed_ops = {'render.render', 'wm.save_as_mainfile'}
    pattern = re.compile(r'bpy\.ops\.(.+?)(?=\s|\(|$)')
    for m in pattern.finditer(code):
        op_name = m.group(1).strip()
        if op_name not in allowed_ops:
            print(f"BLOCKED: bpy.ops.{op_name} запрещён")
            return False
    # Size limit 50KB
    if len(code) > 50 * 1024:
        print("TOO LARGE: код превышает 50 КБ")
        return False
    return True

def send(code):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(120)
    s.connect(('127.0.0.1', 8989))
    s.sendall(code.encode('utf-8'))
    s.shutdown(socket.SHUT_WR)
    chunks = []
    while True:
        d = s.recv(4096)
        if not d: break
        chunks.append(d)
    s.close()
    result = b''.join(chunks).decode().strip()
    print(result)

def main():
    if len(sys.argv) < 2:
        print("Usage: blender_send.py <file> | --stdin")
        sys.exit(1)
    
    if sys.argv[1] == '--stdin':
        code = sys.stdin.read()
    else:
        with open(sys.argv[1], 'r', encoding='utf-8') as f:
            code = f.read()
    
    if not validate(code):
        sys.exit(1)
    send(code)

if __name__ == '__main__':
    main()
