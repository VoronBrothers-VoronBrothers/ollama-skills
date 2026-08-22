---
name: ollama-safe-call
description: Safely call local Ollama models for analysis or code generation. Use when delegating tasks to local models. Every call runs in the background with polling, so no call can be killed or truncated by the 180s bash limit.
---

# Ollama safe call

Use this workflow when calling a local Ollama model from the agent.

## Choose the model

- Analysis, summaries, judgment, simple code: `ornith-1.5-assistant:latest` (fast, ~60 tok/s, honest).
- Complex code, multi-file refactoring, architecture: `qwen3-cod-NEXT-vb-no-promt:latest` (heavy, loads slowly — allow ~700 s for a cold load, budget more time).
- If a lighter model fails twice, escalate to a heavier model.
- Similar names in `ollama list` are usually one base with a modified Modelfile (context/params), not different models.

Verify the exact name with `ollama list` before the first call — a wrong tag (e.g. `ornith:35b` vs the real `ornith-1.5-assistant:latest`) fails instantly with "model not found".

## Build the request

Always write the JSON request to a unique file to avoid shell quoting problems.

Two rules that make the call land on the first try:
- **Set `options.num_predict`** — models have a low default max-output limit, so a long answer gets cut off mid-sentence (`done_reason: "length"`). Set it high enough for the expected answer.
- **Ask for the final answer only** — big models dump their chain-of-thought and can burn the token budget before the actual answer. Instruct: "Верни только финальный ответ, без рассуждений".
- **Optional `options` knobs** — `temperature` (set `0` for deterministic tasks like self-tests or code you'll verify yourself; it only matters for open-ended generation) and `format: "json"` (force a JSON-only response — but only when you actually parse it, and verify the output is valid JSON, since malformed JSON breaks parsing).

### Reasoning mode (only the assistant has it)

- `ornith-1.5-assistant` supports thinking; **`qwen3-cod-NEXT` does NOT have reasoning** — don't send it `reasoning_effort`.
- Set `options.reasoning_effort` per call: **soft priority is `"low"`** — default for cheap checks, summaries, simple code. Raise to `"medium"`/`"high"` only when the task is genuinely complex logic/verification.
- Thinking burns `num_predict` too (it's generated tokens). If `done_reason: "length"` but no final answer, the reasoning ate the budget — raise `num_predict`, don't just retry.
- To keep reasoning separate from the answer, call `/api/chat` and read `message.thinking` + `message.content`; via `/api/generate` thinking is inline in the text.
- `reasoning_effort: "none"` does NOT disable thinking on this model — for cheap calls use `"low"` + small `num_predict` instead.

```bash
# Two labeled variants — pick the one that matches the task:

# (a) Assistant model (has reasoning):
req="/tmp/ollama_req_$(date +%s)_$$.json"
resp="${req%.json}.resp.json"
pidfile="${req%.json}.pid"

cat > "$req" <<'JSON'
{
  "model": "ornith-1.5-assistant:latest",
  "prompt": "Опиши кратко, что нужно сделать. Верни только финальный ответ, без рассуждений. Если это код: только код и self-test.",
  "stream": false,
  "options": {
    "num_predict": 8192,
    "reasoning_effort": "low"
  }
}
JSON

# (b) Code model — NO reasoning, so omit reasoning_effort entirely:
#     model: "qwen3-cod-NEXT-vb-no-promt:latest"
#     options: { "num_predict": 8192 }   # no reasoning_effort key at all
```

For code tasks, explicitly ask for:

- only code, no explanations;
- a self-test or verification command;
- expected behavior for edge cases.
- Recheck expected values yourself BEFORE sending them — the model will faithfully repeat your mistakes.

## Call (always background + polling)

Never call a model in the foreground: the agent's bash kills any command after ~180 s, so even a "fast" call can die mid-generation and lose or truncate the response. Every call — any model, any expected length — uses this one protocol.

1. Launch fully detached (returns instantly, immune to the 180 s limit). **Use `setsid`, not `nohup`**: plain `nohup curl … &` dies between agent tool calls in this harness (its pipes are closed when the calling shell exits); `setsid` + redirecting stdin from `/dev/null` detaches it properly.

```bash
setsid curl -s --max-time 1200 -d @"$req" http://localhost:11434/api/generate \
  -o "$resp" >/tmp/curl.log 2>&1 < /dev/null &
echo $! > "$pidfile"
```

2. Poll with separate short commands (each well under 180 s):

```bash
sleep 60   # heavy models (qwen3-cod-NEXT); use sleep 30 for fast models (ornith)
kill -0 "$(cat "$pidfile")" 2>/dev/null && echo "still running" || echo "curl exited"
jq '{done, done_reason}' "$resp" 2>/dev/null || echo "not ready yet"
```

> **Timeout cascade** — if curl exited (`curl exited`) but `done` is still not `true`, `--max-time` may have cut the request mid-flight. Inspect `/tmp/curl.log` before re-calling: empty log + empty resp = likely server-side issue or a load that was interrupted (see memory ping-pong below), not a simple curl timeout.

Repeat until `done` is `true`, then read the response AND check `done_reason`:

```bash
jq '{done, done_reason, eval_count, response, error}' "$resp"
```

- `done_reason: "stop"` → clean finish.
- `done_reason: "length"` → truncated at `num_predict`. Raise `options.num_predict` and re-call; don't trust a cut-off answer.

Do NOT rely on `pgrep -f "api/generate"` to detect the process — the poll shell matches its own command line and always reports "running". Use the saved PID (`kill -0`).

If curl exited but `done` is not `true`, inspect `/tmp/curl.log` and check whether the model is still loading:

```bash
curl -s http://localhost:11434/api/ps
```

Cold loads take minutes for heavy models — that is normal; keep polling, do not re-launch (a second launch doubles the load). An **empty `/api/ps` during a load is normal**: a loading model only appears once fully loaded.

**Memory ping-pong (important for heavy models)** — only one large model fits in memory at a time; a heavy delegated model does NOT coexist with your own (orchestrator) model. Each of your round-trips between tool calls reloads you and evicts the delegated model, inflating or even restarting its cold load. Mitigate by minimizing round-trips: inside one poll command, use an inner loop (`check; sleep 20` repeated, total ≤ ~170 s) instead of several separate short polls. While you sleep inside bash, the server loads the delegated model uninterrupted — that window is what makes the load finish.

## Verify the result

Do not accept the model's claim that it is done.

- Run generated code or tests yourself.
- Add at least one edge case that the model did not test.
- Independently recheck expected values before blaming the model.
- If the first attempt fails, retry with the concrete error message.
- If the second attempt fails, escalate to a heavier model.
- If the third attempt fails, report the failure honestly.

## Report

After each delegated call, report:

- model used;
- approximate time;
- success or failure;
- what you verified yourself;
- what you corrected or added.
