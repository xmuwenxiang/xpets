# Phase 3 — Acceptance

> Phase-3 closure Acceptance in 4-category form per D-013. Distilled from each Work Spec's §5 plus the Phase-level cumulative rows.

---

## A. By Work Spec

### A.1 SPEC-001 Physics Engine

| Category | Item |
|---|---|
| Performance | `World.step(dt:)` P99 ≤ 0.8 ms / frame on M2 / 12 bodies |
| Performance | Memory delta ≤ 2.5 MB on top of Phase 2 baseline |
| Enumerable | 12-body stack settles in ≤ 60 frames, no NaN, final v ≤ 0.05 m/s |
| Enumerable | NaN injection triggers recovery; world continues stepping |
| Assertable | `ColliderDescriptor(layer: .edge)` is constructable + destroyable (D-003 mandatory symbol) |
| Assertable | BodyHandle value-equality backed by Jolt BodyID |
| Assertable | Physics never imports DPRenderer (SwiftPM target boundary) |
| Regression | All Phase 1 + Phase 2 `acceptance.md` pass; `dt` clamp re-asserted |

### A.2 SPEC-002 Character Physics

| Category | Item |
|---|---|
| Performance | Controller update ≤ 0.1 ms / frame |
| Performance | Memory delta ≤ 0.5 MB |
| Enumerable | Jump→v_y = 5 m/s ± 5 %; landing within ≤ 6 frames |
| Enumerable | Coyote-time ≤ 80 ms; reject after > 100 ms |
| Enumerable | 35° slope ascent ≈ input × cos(35°); 40° → 0 ascent |
| Assertable | `controller.grounded` toggles deterministically around the decay window |
| Assertable | Slope-rejection curve monotone decreasing across 30°, 35°, 40° |
| Assertable | `ColliderDescriptor(layer: .edge)` discard within tick = no memory profile change |
| Regression | `dt` clamp re-asserted; Profiler `.everyFrame` ≤ 0.5 ms |

### A.3 SPEC-003 Secondary Motion

| Category | Item |
|---|---|
| Performance | `SpringSimulation.step` ≤ 50 µs / sub-step on M2 (≤ 6 springs) |
| Performance | Per-tick cost ≤ 0.15 ms (240 Hz sub-stepping at 60 FPS) |
| Performance | Memory delta ≤ 1 MB |
| Enumerable | Tail-spring settles within 0.6 - 1.2 s, overshoot ≤ 15 % |
| Enumerable | 100 s soak: no NaN; max position ≤ 2.0 rad |
| Enumerable | dt = 1/15 ⇒ ≥ 2 internal sub-steps |
| Assertable | `Sendable`-safe across sub-step boundaries (single-thread invariant) |
| Assertable | Step determinism: same target + same dt → FP-bit exact final state |
| Assertable | Overshoot upper bound ≤ 1.15 × targetMagnitude |
| Regression | `spec-001` Acceptance still pass; one `Counter` per Phase-1 tick |

### A.4 SPEC-004 World Reservation (D-003 mandatory)

| Category | Item |
|---|---|
| Performance | `ColliderDescriptor(layer: .edge)` and `Phase5EdgeBridge.noop` add 0 ms / frame when bridge is unset |
| Performance | Memory delta ≤ 64 bytes (single static struct) |
| Enumerable | Construct 100 `ColliderDescriptor(layer: .edge)` then discard — zero world churn |
| Enumerable | Register `.noop`, run 60 frames, register `nil`, run 60 frames — zero `phase5.bridge.call` `Counter` events |
| Assertable | `ColliderDescriptor(layer: .edge)` compiles |
| Assertable | `Phase5EdgeBridge.noop` is `static let` on the protocol |
| Assertable | `PhysicsWorld.step(dt:)` body contains literal `// Phase-5 hookup point:` comment (regex-flagged) |
| Regression | Phase-1 + Phase-2 + `spec-001..spec-003` Acceptance still pass |

---

## B. Phase-3 Cumulative Row

| Category | Item |
|---|---|
| Performance | Profiler `.everyFrame` overhead ≤ 0.5 ms / frame (Phase-1 row 24, re-asserted) |
| Performance | Cumulative Phase-3 memory delta ≤ 4 MB on top of Phase-2 baseline |
| Performance | Total runtime memory worst-case ≤ **136 MB** (Phase 2 132 + Phase 3 4) |
| Enumerable | All SPEC-001..SPEC-004 §5 acceptance items pass |
| Assertable | D-003 reservation symbols (ColliderDescriptor(layer: .edge), Phase5EdgeBridge.noop) reachable from any Phase-3 module |
| Assertable | Phase-3 closure completes with `checklist.md` fully checked |
| Regression | All Phase 1 + Phase 2 `acceptance.md` items pass at end of Phase 3 |

---

## C. Phase-3→Phase-4 Hand-off

- Phase-4 reads `tailSpring.currentAngle` from `DPPhysics.SpringSimulation` (per `spec-003-secondary-motion.md` §2).
- Phase-4 IK does **NOT** consume `Phase5EdgeBridge` — that is a Phase 5a dependency, not Phase 4. Confirmed in `spec-004-world-reservation.md` §4.
