# Phase 7 — AI (Claude Runtime)

> **Status**: Stub — Phase 6 closure gating begins content authoring.
> **Goal**: Bring up Claude CLI as a cohabitating Reasoner. Intent emitted by Claude is delivered to Runtime; Runtime decides how to execute; Skills call back to local or remote tools.
> **Mandatory add-on**: a **Failure Mode Matrix** covering at least 5 typical Claude failure modes and the Pet's degradation strategy.

> ⚠️ **PLACEHOLDER — content authoring begins when Phase 6 closes.** Acceptance prose below is rewritten in 4-category form (D-013) at Phase 7 start.

---

## Goal (Phase 7 final)

Claude is a working Intent producer. When invoked, the Pet speaks, plans, and acts. When Claude is unavailable, the Pet **fails gracefully** back to a local Behavior mode without dropping presence.

---

## Pre-known Deliverables (to be expanded)

- `spec-001-claude-runtime.md` — Lifecycle: launch, stop, IPC, recovery
- `spec-002-claude-ipc.md` — Unix Socket / JSON-RPC / Streaming / Tool Calling
- `spec-003-intent-executor.md` — Intent DSL → Skill dispatch
- `spec-004-skill-runtime.md` — Skill registry, permissions, lifecycle
- `spec-005-built-in-skills.md` — Move / Jump / Sleep / Sit / PlayAnimation / LookAt / OpenApp / Speak
- `spec-006-mcp-bridge.md` — Claude ToolCalling bridge to Skills
- `spec-007-chat-panel.md` — Streaming chat UI (lazy — Phase 9 may polish)
- **`spec-008-failure-mode-matrix.md`** — Mandatory Failure Mode sub-Spec (D-007)

---

## Failure Mode Matrix (mandatory D-007)

At minimum, define degradation for:

| Scenario | Pet Strategy |
|---|---|
| Network offline | Falls back to local Behavior mode; announces "thinking" idle animation |
| Token exhausted | Falls back to local mode; surfaces non-blocking toast |
| Anthropic 5xx | Backs off (exponential), retries; falls back after N |
| Tool Permission Denied | Skill rejects → Intent aborts gracefully → Pet shows confused state |
| Intent parse failure (JSON malformed) | Local retry; if 3 fails, falls back to local-mode |

---

## Out of Scope (Phase 7)

- ❌ Polymorphic AI / Multi-Agent — Phase 9 / Future
- ❌ Long-term Memory attached to Claude's persistent storage (memory is local SQLite from Phase 6)

---

## Risk (placeholder)

- Claude CLI process lifetime vs Runtime lifetime
- IPC overhead vs frame budget
- Tool permission boundaries (Pet cannot run arbitrary `osascript`)
- Network rate limits
- Skill version drift (Phase 9 Marketplace)

---

## Acceptance (placeholder — 4 categories)

- Pet invokes Claude on Cmd-Space; plans a Hop; arrives
- Network offline → pet animates local fallback behavior
- Tool denial → emits visible confused state
- Failure Mode Matrix tested with 5 scenarios passing each

---

## Cross-References

- Phase 6: Skill stub → full Skill Runtime
- Phase 6: Privacy Boundaries carry into Claude reasoning (e.g., never prompt Claude with OCR)
- Phase 9: Marketplace Skill version drift
