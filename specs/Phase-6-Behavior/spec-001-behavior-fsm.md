<!--
Status: Draft
Phase: 6 — Behavior
-->



# SPEC-001 — Behavior FSM (Baseline States)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> Defines the small finite state machine that the Behavior Runtime drives. FSM is intentionally tiny — Utility AI (spec-002) does the heavy lifting between states.

---

## 1. Goal

Provide a baseline FSM for the Behavior Runtime: states are **Idle / Decide / Run / Cleanup**. Each state's entry / exit is observable.

After SPEC-001 ships, the FSM is re-entrant: returning to Idle from any state does NOT leave residual threads / tasks.

---

## 2. Deliverables

- `DPBehavior.BehaviorState` enum: `.idle | .decide | .run | .cleanup`.
- `DPBehavior.BehaviorFSM`:
  - `currentState: BehaviorState`.
  - `transition(to: BehaviorState, reason: String?)` — observable hook.
  - Forbidden transitions logged and rejected (e.g. `.idle → .cleanup` direct).
- Tests:
  - Unit: `idle → decide → run → cleanup → idle` produces transition log of 4 entries.
  - Forbidden: `.idle → .cleanup` direct throws `FSMError.invalidTransition`.
  - Idempotency: re-entering `idle` from `idle` is allowed but emits no log entry.

---

## 3. Out of Scope

- ❌ Behaviors themselves — `spec-002-utility-ai.md`.
- ❌ Memory — `spec-004-memory.md`.

---

## 4. Risk

- **Re-entrancy on enter-Idle** — Mitigation: `cleanup` is a mandatory pass before re-entering Idle; tests assert.
- **State explosion** — Mitigation: 4 states only; new behavior types are added via Utility AI scoring (not new states).

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- `transition(to:reason:)` overhead ≤ 5 µs / call.
- Memory delta ≤ 0.1 MB.
- Profiler budget unchanged.

### Enumerable

- 4-state success path: 4 transitions logged.
- Forbidden direct transition: throws.
- Re-enter Idle: no log entry.

### Assertable

- `BehaviorState` is exhaustive `enum`.
- `transition` is observable via `NotificationCenter` event.

### Regression

- Phase 1..5 Acceptance still pass.
