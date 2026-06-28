<!--
Status: Draft
Phase: 8 — Hardening
-->



# SPEC-001 — Frame Scheduler (60 / 30 / Idle / Sleep)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.

---

## 1. Goal

Adaptive frame-scheduling: full 60 FPS in active mode, 30 FPS in idle (mouse far away), Sleep mode (full pause) when not interacted with for ≥ 30 s.

---

## 2. Deliverables

- `DPHardening.FrameScheduler`:
  - `mode: .full | .idle30 | .sleep`.
  - `tick(dt:)` adapts to mode; `full` clamped to 60 FPS, `idle30` to 30 FPS, `sleep` no-ops.
  - `onUserActivity` event restarts `full` mode.
- Idle time threshold: 30 s → `idle30`; 60 s → `sleep`.
- Tests:
  - Unit: 30 simulated seconds no activity → mode changes to `idle30` at t=30.
  - Unit: 60 simulated seconds no activity → `sleep` at t=60.
  - Unit: mousemove → `full` immediately.
  - Frame budget: `full` 60 FPS sustained; `idle30` 30 FPS sustained; `sleep` 0 draw calls / frame.

---

## 3. Out of Scope

- ❌ Throttling by CPU temperature — Phase 9.

---

## 4. Risk

- **Wakeup on hidden activity** — Mitigation: timer-based fallback; sleep-time ≤ 5 s granularity.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- Mode transitions ≤ 100 ms latency.
- Idle CPU < 1 %, GPU ≤ 5 % in `full` mode.
- Memory delta ≤ 0.5 MB.

### Enumerable

- 30 s idle → idle30.
- 60 s idle → sleep.
- mousemove → full.

### Assertable

- Mode enum exhaustive.
- Threshold constants static.

### Regression

- Phase 1..7 Acceptance still pass.
