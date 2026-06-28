<!--
Status: Draft
Phase: 7 — AI
Owner: TBD
Depends: spec-001-claude-runtime.md
-->

# SPEC-002 — Claude IPC (Unix Socket / JSON-RPC / Streaming / Tool Calling)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> The transport between Claude CLI (child) and the host Runtime.

---

## 1. Goal

Provide a typed, async, error-recovering IPC channel between the Runtime's `ClaudeRuntime` and the Claude CLI child process. The channel uses Unix domain sockets for low-latency local IPC and JSON-RPC for synchronous RPC; streaming is via Server-Sent Events (SSE)-like JSONL over the same socket. Tool Calling is wrapped in a typed `ClaudeToolCall` message.

After SPEC-002 ships, `ClaudeSession.send(prompt:)` round-trip works through this channel; streaming events flow in real-time; tool calls produce typed `ClaudeToolCall` events resolved by `spec-006-mcp-bridge.md`.

---

## 2. Deliverables

- `DPAI.ClaudeIPC`:
  - Unix domain socket at `$TMPDIR/com.desktoppet.claude.sock`.
  - Listener thread on a dedicated `DispatchQueue` (`userInitiated` QoS).
  - JSON-RPC 2.0 envelope: `{ jsonrpc: "2.0", id, method, params, result?, error? }`.
  - Streaming JSONL: newline-delimited events with type-discriminator.
- Message types:
  - `ClaudeRequest { prompt, conversationID, availableTools: [ToolName] }`.
  - `ClaudeIntentResponse { id, kind: .text | .toolCall, ... }`.
  - `ClaudeToolCall { id, name, arguments: [String: AnyCodable] }`.
  - `ClaudeError { code, message, retryable: Bool }`.
- Tests:
  - Unit: send a `ClaudeRequest`, receive a `ClaudeIntentResponse` with kind=.text round-trip.
  - Unit: send a streaming request, receive ≥ 3 JSONL events.
  - Unit: server-side timeout (15 s) → emits `ClaudeError(code: .timeout, retryable: true)`.
  - Failure-mode-inject: malformed JSON from child → Runtime logs and recovers (does NOT crash).
- **API docs**: `api/claude-ipc-api.md` — socket path, message format, threading policy.

---

## 3. Out of Scope

- ❌ Intent DSL — `spec-003-intent-executor.md`.
- ❌ Tool→Skill bridge — `spec-006-mcp-bridge.md`.
- ❌ Persistent IPC history — Phase 9 may add.

---

## 4. Risk

- **Socket path collision** with another process — Mitigation: append PID to path; assert uniqueness at startup.
- **JSON parse race** during streaming — Mitigation: JSONL is demarcated by newline; partial reading is non-blocking.
- **Permission denied** on socket create — Mitigation: runtime falls back to `127.0.0.1:port` (TCP loopback) on macOS sandbox.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- Round-trip P99 ≤ 80 ms for `ClaudeRequest` → `ClaudeIntentResponse` (mock IPC).
- Streaming event latency ≤ 16 ms between child emit and Runtime receipt.
- Memory delta ≤ 2 MB on top of Phase-7 spec-001.

### Enumerable use case

- 100 synthetic round-trips at 1 Hz — all 100 complete successfully.
- Streaming request — ≥ 3 events received.
- Server-side timeout triggered after 15 s — `ClaudeError(.timeout, retryable: true)`.
- Malformed JSON from child — Runtime logs and recovers, never crashes.

### Assertable state

- `ClaudeIPC` thread is single-threaded; messages delivered in order.
- `ClaudeError.retryable` is statically known for each known error code.

### Previous-Phase regression

- Phase 1..6 Acceptance still pass.
