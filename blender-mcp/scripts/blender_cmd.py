#!/usr/bin/env python3
"""
Blender MCP — отправить код в Блендер через supergateway HTTP.

Использование:
    python3 blender_cmd.py "import bpy; print(len(bpy.data.objects))"

Требования:
    - Supergateway на порту 8816 (tmux-сессия mcp-blender)
    - Блендер запущен с аддоном MCP for Blender
"""

import sys
import json
import urllib.request


PORT = 8816
URL = f"http://localhost:{PORT}/mcp"


def send_code(code: str) -> str:
    """Отправить код в Блендер, вернуть результат."""
    payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/call",
        "params": {
            "name": "execute_blender_code",
            "arguments": {"code": code}
        }
    }

    req = urllib.request.Request(
        URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream"
        },
        method="POST"
    )

    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            body = resp.read().decode("utf-8")
    except Exception as e:
        print(f"ERR: не удалось подключиться к Блендеру: {e}")
        sys.exit(1)

    # Парсим SSE-ответ (строки data: ...)
    for line in body.splitlines():
        if line.startswith("data: "):
            data = json.loads(line[6:])
            result = data.get("result", {})
            content = result.get("content", [])
            text = "".join(c.get("text", "") for c in content if c.get("type") == "text")

            if result.get("isError"):
                print(f"ERR: {text.strip()}")
                sys.exit(1)

            # Убираем префикс "Code executed successfully: "
            prefix = "Code executed successfully: "
            if text.startswith(prefix):
                text = text[len(prefix):]

            print(text.strip())
            return text

    print("ERR: пустой ответ от MCP-сервера")
    sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print('Использование: python3 blender_cmd.py "код"')
        sys.exit(1)

    code = sys.argv[1]
    send_code(code)
