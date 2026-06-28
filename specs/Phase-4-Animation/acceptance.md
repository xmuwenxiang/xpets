# Phase 4 — Acceptance

> Phase-4 closure Acceptance in 4-category form per D-013. Distilled from each Work Spec's §5 plus the Phase-level cumulative rows.

---

## A. By Work Spec

### A.1 SPEC-001 BlendTree

| Category | Item |
|---|---|
| Performance | `BlendRuntime.tick(dt:)` P99 ≤ 0.4 ms (32-node graph) |
| Performance | Memory delta ≤ 2 MB |
| Enumerable | Walk → Run over 0.5 s with transition at t=0.5: pose exactly Run (1e-4 noise) |
| Enumerable | Idle + Layer (α=0.05): pose = 95 % Idle + 5 % Ear-twitch |
| Assertable | BlendGraph `Codable` round-trip is stable |
| Assertable | 65-node graph rejected at import time with `BlendGraphError.nodeCountExceeded` |
| Regression | Phase-1 `Animator.tick` semantics unchanged; `Sampling` untouched |

### A.2 SPEC-002 IK Four Variants (D-012)

| Category | Item |
|---|---|
| Performance | P99 IK sum ≤ 1.5 ms; per-solver budgets ≤ 0.05/0.6/0.01/0.4 ms |
| Performance | Profiler budget unchanged |
| Enumerable | Two-Bone 90° exactly within 1e-4 rad |
| Enumerable | CCD tail (6-link) converges ≤ 1 cm within 5 iterations |
| Enumerable | Foot-IK no-op: foot pose unchanged (delta ≤ 1 UM) |
| Enumerable | Look-At: orientation forward ≤ 5° from target direction |
| Assertable | Foot-IK default `init()` is no-op mode |
| Assertable | Look-At angular-priority ease ≤ 4 iterations |
| Assertable | Cross-solver FP-bit identical pose output for same input |
| Regression | Phase-1 Slerp semantics unchanged; Phase 1..3 Acceptance still pass |

### A.3 SPEC-003 Random Idle

| Category | Item |
|---|---|
| Performance | `nextClip(seed:)` ≤ 5 µs / call |
| Performance | Memory delta ≤ 0.5 MB |
| Enumerable | 30 simulated seconds → ≥ 6 distinct picks |
| Enumerable | 100 ms correlation: 50 ms ticks never repeat pick |
| Assertable | `count = 0` or `count > 32` rejected at init |
| Assertable | Deterministic seed policy uses `SplitMix64` |
| Regression | Phase-1 `AnimationClip` machinery unchanged |

### A.4 SPEC-004 AnimationDriver (D-007 signature-only)

| Category | Item |
|---|---|
| Performance | 600-frame run with `.noop` instantiates zero `animation.driver.call` `Counter` events |
| Performance | Memory delta ≤ 64 bytes |
| Enumerable | 1000 × `.noop.apply(offset:.zero, to: 0)` — no observable effect |
| Enumerable | Reflection test: zero Phase-4-owned concrete AnimationDriver conformers |
| Assertable | `AnimationDriver` protocol annotation includes "Phase-5 cross-delivered per D-007" comment |
| Assertable | `allConformingTypes(in: DPAnimation.self, to: AnimationDriver.self)` is empty |
| Assertable | `Phase4AnimationDriver.noop` is a `static let` |
| Regression | Phase-1..3 Acceptance still pass; cumulative Phase 4 ≤ 6 MB delta |

---

## B. Phase-4 Cumulative Row

| Category | Item |
|---|---|
| Performance | Profiler `.everyFrame` overhead ≤ 0.5 ms / frame (Phase-1 row 24, re-asserted) |
| Performance | Cumulative Phase-4 memory delta ≤ 6 MB on top of Phase-3 baseline |
| Performance | Total runtime memory worst-case ≤ **148 MB** (Phase 3 142 + Phase 4 6) |
| Enumerable | All SPEC-001..SPEC-004 §5 acceptance items pass |
| Assertable | D-003 + D-007 reservation symbols (AnimationDriver protocol + `.noop`) reachable from any Phase-4 module |
| Assertable | Phase-4 closure completes with `checklist.md` fully checked |
| Regression | All Phase 1..3 `acceptance.md` items pass at end of Phase 4 |

---

## C. Phase-4 → Phase-5 Hand-off

- Phase 5 takes the `AnimationDriver` protocol from `spec-004-animation-driver.md`, and **may add concrete implementations** in Phase-5 source tree.
- Phase 5 supplies the real `FootIK.target` (ground-topology) — it does NOT modify `spec-002 IK Four Variants` source.
- Phase 5 supplies the real `LookAtIK.target` (cursor) — same.

---

## D. Per-D-012 IK Variant Audit

For traceability, the IK variants locked by D-012 and the inputs they consume:

| D-012 IK Variant | Applied To | Phase-4 input source |
|---|---|---|
| Two-Bone | Ears | Phase-3 `EarSpring.rotation` |
| CCD | Tail chain | Phase-3 `TailSpring.currentAngle` |
| Foot | Fore-legs + hind-legs | Phase-4 no-op default; Phase 5 supplies real target |
| Look-At | Head + Eyes | Phase-4 zero-vector default; Phase 5 supplies cursor |
