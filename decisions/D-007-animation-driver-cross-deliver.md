# D-007 — Animation Driver Cross-Delivered by Phase 5

## Status
Accepted · 2026-06-28

## Context
Phase 4 reserves `AnimationDriver`(Bone, WorldPoint)→apply(offset) signature (D-003). Phase 6 Behavior needs to compile against it (Emotion → Animation Layer driver → AnimationDriver). Without early delivery, Phase 6 is blocked on Phase 4 still implementing the empty body.

## Considered Alternatives
- **A.** Phase 4 ships a working implementation. Risk: Phase 4 owner working outside Phase 4 boundary.
- **B.** Phase 5 cross-delivers the real implementation; Phase 4 ships protocol only. Phase 6 compiles against Phase 5's filled body. **← Chosen.**
- **C.** Phase 6 uses mocks; Phase 7+ retains mocks — permanent.

## Decision
- Phase 4: protocol signature only (per D-003).
- Phase 5: real implementation lands (the `apply(offset)` body reaches Phase 5 world entity references).
- Phase 6: Behavior compiles against Phase 5's filled body.

## Rationale
- Phase 5 the first Phase to have actual world coordinate references — natural place for the implementation.
- Single owner (Phase 5) avoids coordinated edits across Phase 4 / 6.

## Consequences
- (+) Clean ownership: Phase 4 = signature; Phase 5 = body; Phase 6 = consumer.
- (–) Phase 6 enters Build only after Phase 5 is `Done`.

## Trace
- `roadmap.md` §5 (Phase 4 → Phase 5 → Phase 6 arrow)
- `specs/00-spec-conventions.md` §5 (cross-phase delivery note)
- `specs/Phase-4-Animation/overview.md` (World Integration Reservation)
- `specs/Phase-5-DesktopWorld/overview.md` (Pre-known Deliverables, cross-deliver note)
