# Phase 4 — Animation

> **Status**: Stub — Phase 3 closure gating begins content authoring.
> **Goal**: Bring up BlendTree, 4 IK variants (Two-Bone / CCD / Foot / Look-At), Random Idle, Animation Layer. Phase 4 enables Phase 5's Pet-World interaction (legs on the dock must plant via Foot IK).
> **Primary Output**: A fox with rich motion — head pursues cursor, ears twitch, feet plant on slopes, Idle randomly varies, layered expressions stack.

> ⚠️ **PLACEHOLDER — content authoring begins when Phase 3 closes.** Acceptance prose below is rewritten in 4-category form (D-013) at Phase 4 start.

---

## Goal (Phase 4 final)

All four IK types are wired into the rig. BlendTree controls transitions among Walk / Run / Idle / Sit / Sleep / Jump / Eat / Scratch / Stretch / Wash Face / Observe. Random Idle picks among N subtle idle clips. Animation Layer overlays expressions.

---

## Pre-known Deliverables (to be expanded)

- `spec-001-animator.md` — Animator tick + pose assembly
- `spec-002-blendtree.md` — CrossFade, Blend1D, Blend2D, Layer (D-013 acceptance applies)
- `spec-003-ik-system.md` — 4 IK types (Two-Bone, CCD, Foot, Look-At — D-012)
- `spec-004-random-idle.md` — Random Idle picker
- **`spec-NNN-world-reservation.md`** — Phase 5 Animation-Driver hook reservation (mandatory per D-003 / D-007); exact NNN chosen at Phase 4 start

---

## IK Scope (D-012 — locked)

| IK Type | Applied To |
|---|---|
| Two-Bone IK | Ears |
| CCD IK | Tail chain |
| Foot IK | Fore-legs + hind-legs (plant on slope) |
| Look-At IK | Head + Eyes |

---

## Out of Scope (Phase 4)

- ❌ Behavior / Decision → Phase 6
- ❌ Emotion-driven expression changes → Phase 6 (uses Animation Layer as machinery)
- ❌ Claude integration → Phase 7
- ❌ IK on non-Quadrupedal additions (Tail props) → Phase 6

---

## World Integration Reservation (mandatory D-003 / D-007)

- Phase 4's Animation Work Spec defines the `AnimationDriver` interface **signature**: `(Bone, WorldPoint) -> apply(offset)`.
- Used by Phase 5 for Pet reach-and-grab, cursor tracking.
- **Phase 4 ships no implementation** — protocol surface only.
- Per **D-007**, the **real implementation** of this hook is **cross-delivered by Phase 5**, NOT Phase 4. Phase 6 compiles against the signature; Phase 5 fills the body.

---

## Risk (placeholder)

- 4 IK solvers running per frame within 16 ms
- BlendTree node explosion if not bounded
- Random Idle variety vs visual coherence
- Animation Driver reservation must lock with Phase 5 — coordination risk

---

## Acceptance (placeholder — 4 categories)

- Two-Bone IK convergence ≤ N frames at 30° / 60° / 90°
- Foot IK ground-alignment ≥ 99 % on 15° slope
- Look-At IK head-turn latency ≤ 100 ms
- Animation Layer blends stack cleanly with BlendTree base clip

---

## Cross-References

- Phase 1: Skeleton + Idle baseline
- Phase 5: Animation Driver reservation
- Phase 6: Behavior side hooks (Emotion → Layer)
