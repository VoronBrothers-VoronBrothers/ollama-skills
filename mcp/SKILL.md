---
name: mcp
description: "Reminder that the custom TUI fork has built-in MCP support (stdio + streamable HTTP). Use when configuring external MCP servers or checking why no external tools appear. Full format in docs/MCP.md."
---

# MCP — напоминание

В кастомном бинарнике ollama встроена функция MCP: внешние серверы подключаются при старте TUI по `~/.ollama/mcp.json` (stdio-команда или URL). Нет файла → внешних тулз нет, это штатно. Чтобы настроить — создать конфиг; формат и тесты описаны в `/home/voron/.ollama/skills/mcp/docs`.
