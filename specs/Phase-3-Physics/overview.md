# Phase 3 — Physics

> **Status**: Stub — Phase 2 closure gating begins content authoring.
> **Goal**: Integrate Jolt Physics. Add Gravity, Collision, Spring (Tail), Ear spring, Head Tracking. Verify the fox jumps / lands / tail wags / ears swing.
> **Primary Output**: A physics-driven fox with Disney-Physics fidelity (cute over physically absolute).

> ⚠️ **PLACEHOLDER — content authoring begins when Phase 2 closes.** Acceptance prose below is rewritten in 4-category form (D-013) at Phase 3 start.

---

## Goal (Phase 3 final)

Fox can jump, land smoothly, and exhibit secondary motion (tail, ears) via spring simulation. Ground collision works. No fluid sim, no cloth, no destructive physics.

---

## Pre-known Deliverables (to be expanded)

- `spec-001-physics-engine.md` — Jolt World, RigidBody, Constraint, Collision, Gravity
- `spec-002-character-physics.md` — Walk, Jump, Landing, Slope, Obstacle
- `spec-003-secondary-motion.md` — Tail, Ear, Collar — Spring, Inertia, Damping
- **`spec-004-world-reservation.md`** — Phase 5 Collider-Edge hook reservation (mandatory per D-003)

---

## Out of Scope (Phase 3)

- ❌ Physics-based hair / cloth — even fox fur is rigged, not cloth-sim
- ❌ Vehicle / character controller — out per design goals
- ❌ Complex destruction

---

## World Integration Reservation (mandatory D-003)

- Define `Collider.collisionLayer` with extension for `.edge`.
- Reserve a public API for collider attach to abstracted Window/Dock edges for Phase 5a.
- No Phase 3 implementation uses this — interface only.

---

## Risk (placeholder)

- Jolt ↔ Swift bridge ABI stability on Apple Silicon
- Spring tuning for cute vs realistic
- Coordinate mapping between Jolt World and Metal Renderer
- Overlap with Phase 5a Collider-Edge hook contract

---

## Acceptance (placeholder — 4 categories)

- Fox jumps and lands within bounce frame budget
- Tail swing settles within N frames
- Ear flap follows head turn within N frames

---

## Cross-References

- Phase 1: Skeleton + Animation baseline
- Phase 2: PBR (fox must still render correctly when physics-applied)
- Phase 5a: Collider-Edge reservation
