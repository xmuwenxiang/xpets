<!--
Status: Drafts authored (2026-06-28)
Phase: 7 — AI (Claude Runtime)
Owner: TBD
ADRs:  D-006 (Skill stub in Phase 6, real runtime in Phase 7), D-008, D-013; **Mandatory Failure Mode Matrix sub-Spec (no separate ADR; documented in spec-008)**
-->

# Phase 7 — AI (Claude Runtime)

> **Status**: Stub → **Drafts authored (2026-06-28)**. Six Work Specs now exist at Apple Style + 4-category Acceptance; implementation gated on owner review + `Status: Approved`.
> **Goal**: Bring up Claude CLI as a cohabitating Reasoner. Intent emitted by Claude is delivered to Runtime; Runtime decides how to execute; Skills call back to local or remote tools.
> **Mandatory add-on**: a **Failure Mode Matrix** delivered via `spec-008-failure-mode-matrix.md`. Defines degradation paths for ≥ 5 typical Claude failure modes (network, token, 5xx, permission, intent-parse). Phase 7 ships the matrix as an executable test fixture, not just prose.

---

## 1. Goal (Phase 7 final)

Claude is a working Intent producer. When invoked, the Pet speaks, plans, and acts. When Claude is unavailable, the Pet **fails gracefully** back to a local Behavior mode without dropping presence.

After Phase 7 closes, `Cmd-Space` (or equivalent user trigger) launches Claude, who emits an Intent that the Phase-6 Behavior Runtime maps to Skills; Skills update Phase 5 AnimationDriver, which mutates Phase 4 IK chains, producing visible motion. If Claude does not respond in 30 s (network / token / 5xx), the Pet animates a local-fallback and announces "thinking" via idle animation.

---

## 2. Pre-known Deliverables (finalized)

- [`spec-001-claude-runtime.md`](spec-001-claude-runtime.md) — Lifecycle: launch, stop, IPC, recovery.
- [`spec-002-claude-ipc.md`](spec-002-claude-ipc.md) — Unix Socket / JSON-RPC / Streaming / Tool Calling.
- [`spec-003-intent-executor.md`](spec-003-intent-executor.md) — Intent DSL → Skill dispatch.
- [`spec-004-skill-runtime.md`](spec-004-skill-runtime.md) — Skill registry, permissions, lifecycle (consumes Phase-6 Skill stub per D-006).
- [`spec-005-built-in-skills.md`](spec-005-built-in-skills.md) — Move / Jump / Speak / PlayAnimation / LookAt / OpenApp.
- [`spec-006-mcp-bridge.md`](spec-006-mcp-bridge.md) — Claude Tool Calling bridge to Skills (Claude issues a tool call; Skill produces an Intent).
- [`spec-007-chat-panel.md`](spec-007-chat-panel.md) — Streaming chat UI shell (Phase 9 may polish).
- **[`spec-008-failure-mode-matrix.md`](spec-008-failure-mode-matrix.md)** — **Mandatory Failure Mode sub-Spec** — covers ≥ 5 failure modes.

---

## 3. Failure Mode Matrix (mandatory — listed in order of severity)

The matrix covers at minimum:

| Scenario | Pet Strategy | Verifying Test |
|---|---|---|
| **Network offline** | Fallback to local Behavior; animate "thinking" idle | Inject `NWPath.status == .unsatisfied` and assert fallback within 30 s |
| **Token exhausted (429)** | Local fallback; surface non-blocking toast | Inject `429` reply, assert fallback + toast emitted |
| **Anthropic 5xx (500/502/503)** | Exponential backoff (1, 2, 4, 8, 16 s capped at 30); fallback after 5 retries | Inject 500, assert backoff schedule via timestamps |
| **Tool Permission denied** | Skill aborts gracefully; Pet shows confused state | Simulator denies 1 tool; assert confused animation + recovery after 1 s |
| **Intent parse failure (JSON malformed)** | Local retry × 3; fallback to local-mode if all fail | Inject malformed JSON; assert 3 retries, then fallback |

---

## 4. Out of Scope (Phase 7)

- ❌ Polymorphic AI / Multi-Agent — Phase 9 / Future.
- ❌ Long-term Memory attached to Claude's persistent storage — memory is local SQLite from Phase 6.
- ❌ Vision Pro / AR port — post-Phase-9 roadmap.
- ❌ Multi-Pet AI dispatch — post-Phase-9 roadmap.

---

## 5. Skill Cross-deliverable (D-006)

Per **D-006**, Phase 6 ships the Skill **stub** (data type only); Phase 7 fills the real runtime. At Phase-7 closure:

- `DPBehavior.Skill` (Phase-6 type) is now a fully registered runtime with permission checks, lifecycle, and telemetry hooks.
- Phase-6 acceptance row (`SkillErrorMissing` etc.) now reports the real error, not the stub.

---

## 6. Risk (placeholder — to be expanded at Phase-7 kickoff)

- **Claude CLI process lifetime vs Runtime lifetime** — Mitigation: `claudeRuntime` is a child process; on Runtime shutdown, the child receives `SIGTERM` and exits cleanly within 5 s. Tests assert.
- **IPC overhead vs frame budget** — Mitigation: IPC is **async** and out-of-band; Runtime never blocks on IPC read; Intent delivery is queued and processed at the next `Runtime.tick(dt:)`.
- **Tool permission boundaries (Pet cannot run arbitrary `osascript`)** — Mitigation: Skill permission enum (`readScreen` / `move` / `speak` / etc.); Claude's Tool Calling only invokes Skills whose permission is `grantedByUser` on first-use; `osascript`-equivalent is **default-denied** for any Skill.
- **Network rate limits** — Mitigation: 429 handling in Failure Mode matrix; periodic `cmd-test` allows manual override.
- **Skill version drift (Phase 9 Marketplace)** — Mitigation: Phase-7 ships a `Skill.version` field; Phase-9 Marketplace layer wraps version-pinning.

---

## 7. Acceptance (placeholder — 4-category form finalized in `acceptance.md`)

See [`acceptance.md`](acceptance.md). Cumulative Phase-7 memory delta target: **≤ 8 MB** on top of Phase-6 baseline (≤ 168 MB worst-case at end-of-Phase-7). Profiler `.everyFrame` overhead ≤ 0.5 ms / frame (Phase-1 row 24).

---

## 8. Cross-References

- **Phase 1**: `spec-003-runtime.md` (Runtime.tick must integrate Claude intent).
- **Phase 4**: `spec-004-animation-driver.md` + Phase-5 implementation (`Phase5AnimationDriver`) — Skills call AnimationDriver to move the fox.
- **Phase 5**: `spec-004-desktop-world.md` (Skills speak to entities; AnimationDriver mutates bones).
- **Phase 6**: Skill stub → real Skill Runtime (D-006 cross-deliverable), Privacy Spec (Claude must never receive OCR-derived content).
- **Phase 9**: Marketplace Skill version drift.
- **ADRs**: D-006 (Skill cross-deliverable), D-008, D-013.
