# D-003 — World Integration Reservation (Phase 3 + Phase 4)

## Status
Accepted · 2026-06-28

## Context
Phase 5 (Desktop World) needs interface hooks for Phase 3 (Physics) and Phase 4 (Animation). Without advance reservation, Phase 5 either rewrites Layer / Driver APIs (refactor cost) or ships with hacky cross-Phase coupling. Phase 1–2 cannot observe Pet–World interaction yet.

## Considered Alternatives
- **A.** Phase 5 forks the Renderer/Animation code to inject hooks. **← Rejected.**
- **B.** Phase 3 + Phase 4 reserve the method signature only; Phase 5 fills the body via cross-phase delivery. **← Chosen.**
- **C.** Phase 5 designs its own abstraction; defers Phase 3/4 integration to Phase 8 (Hardening).

## Decision
- **Phase 3 (Physics)** reserves `Collider.collisionLayer` extension to `.edge` for Dock / Window edge collisions.
- **Phase 4 (Animation)** reserves `AnimationDriver` method signature `(Bone, WorldPoint) -> apply(offset)` for reach-and-grab interactions.
- Both Phases ship **interface only** — no body. Real implementation arrives in Phase 5 (D-007).

## Rationale
- Keeps Phase 3–4 spec surface tight while letting Phase 5 integrate without refactor.
- Each reservation is a single method signature plus a one-line protocol declaration.

## Consequences
- (+) Phase 5 integrates without Phase 3 / 4 regression risk.
- (+) Phase 6 Behavior code can compile against the `AnimationDriver` signature even before Phase 5 fills it (stub returns identity).
- (–) Reservation must not be re-interpreted later. Lint rule against honoring via inaccurate name shadowing.

## Trace
- `specs/00-spec-conventions.md` §5
- `specs/Phase-3-Physics/overview.md` (mandatory D-003 section)
- `specs/Phase-4-Animation/overview.md` (mandatory D-003 / D-007 section)
