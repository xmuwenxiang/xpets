# Phase 7 — Acceptance

> Phase-7 closure Acceptance in 4-category form per D-013. Distilled from each Work Spec's §5 plus the Phase-level cumulative rows.

---

## A. By Work Spec

### A.1 SPEC-001 Claude Runtime (Lifecycle)

| Category | Item |
|---|---|
| Performance | `ClaudeSession.send(prompt:)` round-trip ≤ 1.2 s P99 (mock IPC, 100 prompts) |
| Performance | Memory delta ≤ 1 MB |
| Enumerable | `start()` → `.ready` within 10 s |
| Enumerable | `stop()` → child exited within 5 s |
| Enumerable | Crash × 3 in 60 s → restart, restart, restart; 4th → `.degraded` |
| Assertable | Singleton invariant: one ClaudeRuntime per Application |
| Assertable | Lifecycle states are exhaustive enum |
| Regression | Phase 1..6 Acceptance still pass; Profiler budget unchanged |

### A.2 SPEC-002 Claude IPC

| Category | Item |
|---|---|
| Performance | Round-trip P99 ≤ 80 ms |
| Performance | Streaming event latency ≤ 16 ms |
| Performance | Memory delta ≤ 2 MB |
| Enumerable | 100 round-trips @ 1 Hz — all 100 succeed |
| Enumerable | Streaming — ≥ 3 events received |
| Enumerable | Server timeout (15 s) → `ClaudeError(.timeout, retryable: true)` |
| Enumerable | Malformed JSON → Runtime logs + recovers |
| Assertable | Single-threaded IPC; messages in order |
| Regression | Phase 1..6 Acceptance still pass |

### A.3 SPEC-003 Intent Executor

| Category | Item |
|---|---|
| Performance | `IntentExecutor.execute` P99 ≤ 5 ms |
| Performance | Memory delta ≤ 0.5 MB |
| Enumerable | 7 intent cases routed correctly |
| Enumerable | Missing-skill → `.failure(.skillMissing)` |
| Enumerable | Malformed → `.failure(.parseError)` |
| Enumerable | Round-trip: `.move` intent → fox slides to target via AnimationDriver |
| Assertable | `Intent` is `Codable` round-trip stable |
| Regression | Phase-5 AnimationDriver wire unchanged |

### A.4 SPEC-004 Skill Runtime (D-006 cross-deliverable)

| Category | Item |
|---|---|
| Performance | Registration overhead ≤ 50 µs / skill |
| Performance | Invocation overhead ≤ 0.5 ms P99 (excludes Skill work) |
| Performance | Memory delta ≤ 1 MB |
| Enumerable | 5 Skills registered, count assertion |
| Enumerable | SpeakSkill invoke with permission granted → success |
| Enumerable | Same invoke with permission denied → throws |
| Enumerable | Lifecycle ordering: preInvoke → invoke → postInvoke → cleanup |
| Assertable | `SkillRegistry` Sendable-safe |
| Assertable | `Skill.requiredPermissions` is statically declared |
| Assertable | `Skill.version` mandatory (registry refuses nameless versions) |
| Regression | Phase-6 Skill stub continues to compile |

### A.5 SPEC-005 Built-in Skills

| Category | Item |
|---|---|
| Performance | Per-Skill invocation overhead ≤ 0.5 ms P99 |
| Performance | MoveSkill intent → Bone mutation ≤ 16 ms wall-clock |
| Performance | Memory delta ≤ 2 MB |
| Enumerable | 8 Skills registered |
| Enumerable | MoveSkill moves fox by exact target distance within 60 frames |
| Enumerable | SpeakSkill (Phase-7 stub) emits SkillResult without crashing audio |
| Assertable | All 8 Skills have `requiredPermissions` matching the table |
| Assertable | version-pin: each Skill `version == "1.0.0"` |
| Regression | Phase-4 IK + Phase-5 AnimationDriver unchanged |

### A.6 SPEC-006 MCP Bridge

| Category | Item |
|---|---|
| Performance | `bridge(toolCall:)` P99 ≤ 5 ms |
| Performance | Memory delta ≤ 0.5 MB |
| Enumerable | 6 default mappings work |
| Enumerable | `unmapped_tool` → failure |
| Enumerable | `read_screen` always denied |
| Assertable | `read_screen` denial policy is `static let` in source |
| Regression | Phase-6 Privacy visibility contract: Claude never receives OCR |

### A.7 SPEC-007 Chat Panel

| Category | Item |
|---|---|
| Performance | Streaming render P99 ≤ 16 ms / frame |
| Performance | Memory delta ≤ 2 MB |
| Enumerable | Refresh → text populates within 1 s |
| Enumerable | Stop mid-stream → frozen text |
| Enumerable | 10 RPS spam → 1 RPS honored |
| Assertable | Stable accessibility IDs for Stop/Refresh |
| Assertable | UTF-8 boundary test passes |
| Regression | Phase-1 Overlay window unaffected |

### A.8 SPEC-008 Failure Mode Matrix (Mandatory)

| Category | Item |
|---|---|
| Performance | Fallback transition latency ≤ 6 frames (≤ 100 ms) per FM |
| Performance | Memory delta ≤ 0.5 MB |
| Enumerable | FM-1 offline → Idle-Sad animation |
| Enumerable | FM-2 429 → toast emitted |
| Enumerable | FM-3 5xx → backoff schedule observed (1,2,4,8,16 s) → fallback after 5 |
| Enumerable | FM-4 permission denied → Confused animation → recovery 1 s |
| Enumerable | FM-5 3 retries → fallback |
| Assertable | `FailureModeRegistry` has exactly 5 default rows at boot |
| Assertable | Each row has unique `id` (FM-1..FM-5) |
| Assertable | `TelemetryEvent.fallbackUsed(mode:)` emitted exactly once per fallback |
| Regression | Phase 1..6 Acceptance still pass; Profiler budget unchanged |

---

## B. Phase-7 Cumulative Row

| Category | Item |
|---|---|
| Performance | Profiler `.everyFrame` overhead ≤ 0.5 ms / frame (Phase-1 row 24, re-asserted) |
| Performance | Cumulative Phase-7 memory delta ≤ 8 MB on top of Phase-6 baseline |
| Performance | Total runtime memory worst-case ≤ **168 MB** (Phase 6 160 + Phase 7 8) |
| Enumerable | All SPEC-001..SPEC-008 §5 acceptance items pass |
| Assertable | D-006 cross-deliverable proven: Phase-6 stub is now a real runtime |
| Assertable | Phase-7 closure completes with `checklist.md` fully checked |
| Regression | All Phase 1..6 `acceptance.md` items pass at end of Phase 7 |

---

## C. D-006 Cross-Deliverable Proof

Phase 7 closes the D-006 obligation: Phase 6 ships Skill as a **stub**; Phase 7 ships the **real runtime**. At Phase-7 closure, a reflection test asserts:

| Module | Expected conformer count for `Skill` protocol |
|---|---|
| `DPBehavior` (Phase 6 stub) | 1 (the stub itself — declared for reference but not invoked) |
| `DPBehavior.Skills` (Phase-7 source) | ≥ 8 (`Move`, `Jump`, `Sleep`, `Sit`, `PlayAnimation`, `LookAt`, `OpenApp`, `Speak`) |

This test must pass for Phase-7 to close.

---

## D. Privacy Boundary Audit (Phase-6 forward into Phase-7)

For traceability, every Phase-7 channel where Claude's IPC could leak data must respect the Phase-6 Privacy visibility contract:

| Phase-7 Channel | Phase-6 Constraint |
|---|---|
| `ClaudeToolCall.arguments` | `read_screen` is **default-denied** in `spec-006-mcp-bridge.md` |
| `Intent` payload | `speak(text)` text never originates from a `.sensitive` entity |
| `ChatPanel` UI | Chat history is not OCR-able from outside (no clipboard export) |
| `Telemetry` | `fallbackUsed(mode:)` does not include sensitive text |

These four constraints are tested at Phase-7 closure.
