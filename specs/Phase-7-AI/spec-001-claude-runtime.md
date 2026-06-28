<!--
Status: Draft
Phase: 7 — AI
Owner: TBD
-->

# SPEC-001 — Claude Runtime (Lifecycle)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> Phase-7 backbone. Owns the Claude CLI child process lifecycle: launch, stop, IPC, recovery. The runtime is a singleton wired into the Phase-1 Runtime tick.

---

## 1. Goal

Bring up a child process supervisor that launches the Claude CLI as an external process, exposes a typed lifecycle, and recovers from crashes. After SPEC-001 ships, `claudeRuntime.start()` produces a working Claude session; `claudeRuntime.stop()` shuts it down cleanly within 5 s; crashed sessions auto-restart up to N times before yielding to the Failure Mode Matrix.

---

## 2. Deliverables

- `DPAI.ClaudeRuntime`:
  - Singleton-ish: a single instance owned by the Application context.
  - `func start() throws` — spawns `claude` binary with the Phase-7-specific args.
  - `func stop(timeout: TimeInterval) async` — sends `SIGTERM`; on timeout, `SIGKILL`.
  - `func session(id: UUID) -> ClaudeSession` — typed accessor for an active session.
- `DPAI.ClaudeSession`:
  - `id: UUID`, `pid: Int32`, `startedAt: Date`, `state: .starting | .ready | .degraded | .crashed`.
  - `events: AsyncStream<ClaudeEvent>` — typed events from the IPC layer (`spec-002`).
  - `func send(prompt: String) async throws -> IntentEnvelope`.
- Recovery policy:
  - Auto-restart on crash ≤ 3 times within 60 s.
  - ≥ 3 crashes within 60 s → state becomes `.degraded`; Failure Mode Matrix takes over.
- Tests:
  - Unit: `start()` spawns process with the expected `argv`.
  - Unit: `stop()` after a healthy session emits `claude.session.stopped` event, and child pid has exited within 5 s.
  - Unit: simulate child crash (kill -9 from a test); assert ≤ 3 restarts within 60 s produce `.ready`; the 4th triggers `.degraded`.
  - Integration: Phase-1 `Runtime.tick` integrates the lifecycle event stream without blocking.
- **API docs**: `api/claude-runtime-api.md` — lifecycle states, recovery policy, threading.

---

## 3. Out of Scope

- ❌ **IPC protocol** — `spec-002-claude-ipc.md`.
- ❌ **Intent DSL** — `spec-003-intent-executor.md`.
- ❌ **Skill registry** — `spec-004-skill-runtime.md`.

---

## 4. Risk

- **Child process orphan on Runtime crash** — Mitigation: Runtime registers an `atexit`-style cleanup hook that calls `claudeRuntime.stop()`.
- **Long startup time** (>5 s) on first launch due to model warm-up — Mitigation: `state = .starting` is observable; Tests assert startup completes within 10 s on `macos-14`.
- **Zombie processes** from crash recovery — Mitigation: `wait4` after each child restart; assert no zombie.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- `ClaudeSession.send(prompt:)` round-trip ≤ 1.2 s P99 over 100 synthetic prompts with mock IPC.
- Memory delta ≤ 1 MB on top of Phase-6 baseline.
- Profiler budget unchanged.

### Enumerable use case

- `start()` → state becomes `.ready` within 10 s.
- `stop()` → child pid exited within 5 s.
- Crash × 3 within 60 s → restart, restart, restart; 4th crash → state becomes `.degraded`.

### Assertable state

- Singleton invariant: only one `ClaudeRuntime` per Application.
- `state` transitions are deterministic and typed (`enum` exhaustive).
- Recovery policy is fixed (3 restarts / 60 s) and configurable only via `DPFoundation.Config`.

### Previous-Phase regression

- Phase 1..6 `acceptance.md` items still pass.
- Phase-1 `Runtime.tick` semantics unchanged.
- Profiler `.everyFrame` overhead unchanged.
