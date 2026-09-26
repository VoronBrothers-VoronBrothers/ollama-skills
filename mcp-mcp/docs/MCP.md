# External MCP tools in the TUI fork

This fork of Ollama can connect external Model Context Protocol (MCP) servers at startup and register their tools alongside the built-in agent tools. Two transports are supported: **stdio** (spawn a local command) and **streamable HTTP** (remote endpoint).

SDK used: [`github.com/modelcontextprotocol/go-sdk`](https://github.com/modelcontextprotocol/go-sdk).

## Config file

Create `~/.ollama/mcp.json`:

```json
{
  "servers": [
    { "name": "fs",   "command": "/usr/local/bin/fs-mcp-server" },
    { "name": "web",  "url": "https://mcp.example.com/mcp" },
    { "name": "git",  "command": "git-mcp", "args": ["--repo", "."], "env": {"GIT_REPO_PATH": "/srv/repo"} }
  ],
  "require_approval": true
}
```

Fields per server:

| Field       | Meaning                                                        | Required |
|-------------|----------------------------------------------------------------|----------|
| `name`      | Label for the server (used in logs and name prefixes)          | optional (defaults to `serverN`) |
| `command`   | Local program to spawn with stdio transport                    | one of `command`/`url` |
| `args`      | Arguments passed after `command`                               | —        |
| `env`       | Extra environment variables for the spawned process            | —        |
| `url`       | Streamable HTTP endpoint (`POST /mcp`)                        | one of `command`/`url` |

Global flag:

- `"require_approval"` (default `true`): when true, every MCP tool asks for user confirmation before it runs. Set to `false` to let the agent call them without asking.

A missing config file is fine — no external tools are added and the TUI starts normally. Servers that fail to start or list tools are skipped with a warning on stderr; they never abort the session.

## Workflow: storing `mcp.json` outside `~/.ollama`

The live config file is `~/.ollama/mcp.json`. Do **not** keep it there permanently — archive and retrieve it through the docs folder:

1. **Before work**: copy the needed config from `/home/voron/.ollama/skills/mcp/docs` into `~/.ollama/mcp.json`, then start the TUI.
2. **After use**: move (archive) `~/.ollama/mcp.json` back to `/home/voron/.ollama/skills/mcp/docs` — into the corresponding subfolder for that server/config — and remove it from `~/.ollama/`, so the next run starts without external MCP servers.

This keeps `~/.ollama/` clean between sessions while preserving reusable configs under docs.

## How tools appear in the TUI

- Each remote tool keeps its original name (e.g. `echo`, `web_search`).
- If two servers expose the same tool, or it collides with a built-in tool, the registry prefixes it with the server name: `srvB_echo`. A pathological double collision gets a numeric suffix (`srv_3`).
- Tool descriptions come from the MCP server; schemas are mapped into Ollama's function schema (object/properties/required/items/enum/$defs). Exotic constructs degrade to a minimal object schema.

## Running

No extra step: just start the custom TUI as usual. All configured servers connect during startup and their tools show up in the agent tool list. Sessions are closed when the TUI exits.

```sh
ollama          # or however you launch your fork's TUI binary
```

To watch what happens with MCP at startup, run with stderr visible; each failed server prints a `warning: mcp server "name" failed to start: ...` line.

## Example: minimal stdio server (Go)

For reference/testing — see `agent/mcps/internal/mocksrv/main.go` in this repository. It implements two tools (`echo`, `boom`) over stdio with the go-sdk and is used by the test suite via `go run ./internal/mocksrv`.

Any MCP server that speaks stdio or streamable HTTP (Python, TypeScript, Go...) works: point a `command`/`url` at it in `mcp.json`.

## Verification / tests

```sh
cd "ollama fork our fork"   # repo root
go build ./...
go vet ./agent/mcps/...
go test ./agent/mcps/...
```

The package `agent/mcps` covers: schema mapping, stdio connect (real subprocess via go run mock), streamable HTTP connect (in-process httptest server), name-collision prefixing, config validation and the approval default.

## Rollback

This feature is fully self-contained; to remove it: delete `agent/mcps/`, revert the two changes in `cmd/agent_tui.go` (the import + the pool wiring inside `GenerateAgentTUI` / `agentToolsRegistry`), drop the go-sdk dependency from `go.mod`/`go.sum`.
