#!/usr/bin/env python3
"""MCP stdio server for the Prizrak-Box (Pandora/Clash) VPN.

Controls the local Mihomo/clash-meta external controller via HTTP.
Base: http://127.0.0.1:9686   Auth: Authorization: Bearer <token>

Tools:
  prizrak_status()         -> version, routing mode, TUN enable, mixed-port
  list_proxies(group)      -> group info + current node (`now`) + all node names (default GLOBAL)
  select_proxy(group,name) -> set active node of a group (PUT /proxies/{group}) and verify via `now`
  get_rules()              -> routing rules

Raw MCP stdio: JSON-RPC 2.0, newline-delimited lines, no external deps.
"""
import json
import os
import sys
import urllib.error
import urllib.request

BASE = os.environ.get("PRIZRAK_BASE", "http://127.0.0.1:9686")
TOKEN = os.environ.get("PRIZRAK_TOKEN", "17Rse39Dmvb4qpbu")


def http(method, path, body=None):
    url = BASE + path
    headers = {"Authorization": "Bearer %s" % TOKEN, "Content-Type": "application/json"}
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    with urllib.request.urlopen(req, timeout=10) as r:
        raw = r.read()
        try:
            return json.loads(raw.decode("utf-8")) if raw else {}
        except Exception:
            return {"__raw": raw.decode("utf-8", "replace")}


def prizrak_status():
    d = {}
    try:
        d["version"] = (http("GET", "/version") or {}).get("version")
    except urllib.error.URLError as e:
        d["error"] = str(e)
    try:
        cfg = http("GET", "/configs") or {}
        tun = cfg.get("tun") or {}
        d["mode"] = cfg.get("mode")
        d["mixed_port"] = cfg.get("mixed-port")
        d["tun_enable"] = bool(tun.get("enable"))
    except urllib.error.URLError as e:
        d.setdefault("error", str(e))
    return {"ok": "error" not in d, **d}


def list_proxies(group="GLOBAL"):
    try:
        data = http("GET", "/proxies/%s" % group) or {}
    except urllib.error.URLError as e:
        return {"error": "cannot read /proxies/%s: %s" % (group, str(e))}
    if not isinstance(data, dict):
        return {"ok": True, "group": group, "all": [], "now": None, "type": None}
    return {"ok": True, "group": data.get("name", group),
            "type": data.get("type"),
            "now": data.get("now"),
            "alive": bool(data.get("alive")),
            "all": data.get("all") or []}


def select_proxy(group="GLOBAL", name=""):
    if not name:
        return {"error": "name required"}
    err = None
    for method in ("PUT", "POST"):
        try:
            http(method, "/proxies/%s" % group, {"name": name})
            break
        except urllib.error.URLError as e:
            err = str(e)
    if err is not None:
        return {"error": "select failed (%s)" % err}
    cur = ""
    try:
        data = http("GET", "/proxies/%s" % group) or {}
        cur = (data.get("now") if isinstance(data, dict) else "") or ""
    except Exception:
        pass
    return {"ok": True, "group": group, "requested": name, "current_selected": cur}


def get_rules():
    try:
        return {"ok": True, "rules": http("GET", "/rules") or []}
    except urllib.error.URLError as e:
        return {"error": str(e)}


TOOLS = [
    {"name": "prizrak_status",
     "description": "Prizrak-Box (Pandora/Clash) status: version, routing mode, TUN enable, mixed-port.",
     "inputSchema": {"type": "object", "properties": {}, "required": []}},
    {"name": "list_proxies",
     "description": "List a proxy-group's nodes and current selection. group default GLOBAL.",
     "inputSchema": {"type": "object",
                    "properties": {"group": {"type": "string", "default": "GLOBAL"}},
                    "required": []}},
    {"name": "select_proxy",
     "description": "Switch the active node of a proxy-group (e.g. GLOBAL). name required.",
     "inputSchema": {"type": "object",
                    "properties": {"group": {"type": "string", "default": "GLOBAL"},
                                  "name": {"type": "string"}},
                    "required": ["name"]}},
    {"name": "get_rules",
     "description": "Return the routing rules of the Prizrak-Box config.",
     "inputSchema": {"type": "object", "properties": {}, "required": []}},
]


def call_tool(name, args):
    args = args or {}
    try:
        if name == "prizrak_status":
            return prizrak_status()
        if name == "list_proxies":
            return list_proxies(args.get("group", "GLOBAL"))
        if name == "select_proxy":
            return select_proxy(args.get("group", "GLOBAL"), args.get("name", ""))
        if name == "get_rules":
            return get_rules()
    except Exception as e:
        return {"error": repr(e)}
    return {"error": "unknown tool %s" % name}


def handle(msg):
    mtype = msg.get("method")
    id_ = msg.get("id")
    if not mtype or mtype in ("notifications/initialized",):
        return None, None
    if mtype == "initialize":
        body = {"protocolVersion": "2024-11-05",
               "capabilities": {"tools": {}},
               "serverInfo": {"name": "prizrak-box-mcp", "version": "1.0.0"}}
    elif mtype == "ping":
        body = {}
    elif mtype == "tools/list":
        body = {"tools": TOOLS}
    elif mtype == "tools/call":
        params = msg.get("params") or {}
        res = call_tool(params.get("name"), params.get("arguments") or {})
        body = {"content": [{"type": "text",
                            "text": json.dumps(res, ensure_ascii=False)}],
               "isError": bool(res.get("error"))}
    else:
        return id_, None  # unknown -> -32601 in main
    return id_, body


def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except Exception:
            print(json.dumps({"jsonrpc": "2.0", "id": None,
                             "error": {"code": -32700, "message": "Parse error"}}), flush=True)
            continue
        mtype = msg.get("method")
        if not mtype:
            continue  # malformed/empty method; ignore
        id_, body = handle(msg)
        out = {"jsonrpc": "2.0", "id": msg.get("id")}
        if body is None and mtype != "notifications/initialized":
            out["error"] = {"code": -32601, "message": "Method not found"}
        elif body is None:
            continue  # notification without response
        else:
            out["result"] = body
        print(json.dumps(out), flush=True)


if __name__ == "__main__":
    main()
