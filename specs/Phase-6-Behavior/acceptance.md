# Phase 6 — Acceptance

> Phase-6 closure Acceptance in 4-category form per D-013.

---

## A. By Work Spec

### A.1 SPEC-001 Behavior FSM

| Category | Item |
|---|---|
| Performance | `transition` ≤ 5 µs / call |
| Performance | Memory delta ≤ 0.1 MB |
| Enumerable | 4-state success path → 4 transitions |
| Enumerable | Forbidden direct transition → throws |
| Enumerable | Re-enter Idle → no log entry |
| Assertable | `BehaviorState` is exhaustive `enum` |
| Regression | Phase 1..5 Acceptance still pass |

### A.2 SPEC-002 Utility AI

| Category | Item |
|---|---|
| Performance | `next(...)` P99 ≤ 0.2 ms |
| Performance | Memory delta ≤ 0.5 MB |
| Enumerable | High-energy + low-curiosity + daytime → explore |
| Enumerable | Low-energy + nighttime → sleep |
| Enumerable | 1000 deterministic calls FP-bit exact |
| Assertable | `Sendable`-safe |
| Regression | Phase 1..5 Acceptance still pass |

### A.3 SPEC-003 Emotion

| Category | Item |
|---|---|
| Performance | `EmotionEngine.tick` P99 ≤ 0.1 ms |
| Performance | Memory delta ≤ 0.5 MB |
| Enumerable | 60-frame tick → energy -0.05 |
| Enumerable | +0.1 happiness moves up 0.1 next tick |
| Assertable | Rate bounds are `static let` |
| Regression | Phase 1..5 Acceptance still pass |

### A.4 SPEC-004 Memory

| Category | Item |
|---|---|
| Performance | Insert ≤ 100 µs P99; FTS5 ≤ 1 ms P99 |
| Performance | Memory delta ≤ 2 MB |
| Enumerable | Insert 100 → evict 50 → count = 50 |
| Enumerable | FTS search returns matches |
| Enumerable | Sensitive payload rejected |
| Assertable | WAL mode enabled at boot |
| Regression | Phase 1..5 Acceptance still pass |

### A.5 SPEC-005 Daily Routine

| Category | Item |
|---|---|
| Performance | `currentBucket` ≤ 1 µs |
| Performance | Memory delta ≤ 0.1 MB |
| Enumerable | 8 a.m. → morning |
| Enumerable | 3 p.m. → afternoon |
| Assertable | Boundary constants static |
| Regression | Phase 1..5 Acceptance still pass |

### A.6 SPEC-006 Privacy & Behavior Boundaries (Mandatory)

| Category | Item |
|---|---|
| Performance | `BoundaryGuard.check` P99 ≤ 1 µs |
| Performance | Memory delta ≤ 1 MB |
| Enumerable | 5 default-deny operations rejected |
| Enumerable | Read-screen Skill rejected |
| Enumerable | Audit log: 6 boundary events |
| Assertable | Default-deny list is `static let` |
| Assertable | Boundary Guard is the *only* Skill.invoke path (reflection) |
| Regression | Phase 1..5 Acceptance still pass; Phase-7 cross-references §D satisfied |

### A.7 SPEC-007 Skill Stub (D-006 cross-deliverable)

| Category | Item |
|---|---|
| Performance | Memory delta ≤ 64 bytes |
| Performance | 0 ms / frame (stub never invoked) |
| Enumerable | Stub exists; zero conformers |
| Assertable | Reflection: zero Phase-6-owned concrete conformers |
| Assertable | `Skill` comment annotation present |
| Regression | Phase 1..5 Acceptance still pass |

---

## B. Phase-6 Cumulative Row

| Category | Item |
|---|---|
| Performance | Profiler `.everyFrame` ≤ 0.5 ms / frame (Phase-1 row 24) |
| Performance | Cumulative Phase-6 memory delta ≤ 4 MB on top of Phase-5 baseline |
| Performance | Total runtime memory worst-case ≤ **164 MB** (Phase 5 160 + Phase 6 4) |
| Enumerable | All SPEC-001..SPEC-007 §5 acceptance items pass |
| Assertable | D-006 cross-deliverable stub-half proven: zero `DPBehavior`-owned concrete Skill conformers |
| Assertable | Privacy default-deny list enforced at every Skill boundary |
| Regression | All Phase 1..5 `acceptance.md` items pass at end of Phase 6 |

---

## C. D-006 Cross-Deliverable Proof

Phase 6 closes the stub half of D-006; Phase 7 closes the real half. At Phase-6 closure, a reflection test asserts (and must pass):

| Module | Expected `Skill` conformer count |
|---|---|
| `DPBehavior` (Phase-6 source) | 0 |
| All other modules | 0 |

At Phase-7 closure the assertion becomes:

| Module | Expected `Skill` conformer count |
|---|---|
| `DPBehavior` (Phase-6 stub) | 1 (the stub type itself, structurally present) |
| `DPAI.Skills` (Phase-7 source) | ≥ 8 (built-in skills) |

---

## D. Privacy Contract Forward to Phase-7

Phase-6 Privacy Spec is **enforced** at every Phase-7 IPC / Intent / Chat channel. Phase-7 acceptance.md § D (Privacy Boundary Audit) checks the four constraints:

1. `read_screen` Skill → default-denied at MPC Bridge level (Phase-7 spec-006).
2. Speak(text) origin → never from `.sensitive` entity (Phase-6 Privacy mapping).
3. Chat history → not OCR-able externally.
4. `TelemetryEvent.fallbackUsed(mode:)` payload → no sensitive text.
