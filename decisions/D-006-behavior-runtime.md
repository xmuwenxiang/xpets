# D-006 — Local Behavior Runtime + Skill Stub (Phase 6)

## Status
Accepted · 2026-06-28

## Context
The AI Runtime (Phase 7) needs a Skill concept to clamp Claude's Intent. If Skill is invented fresh in Phase 6, it must already support what Phase 7 needs — failure leads to a refactor cycle. Conversely, if Phase 6 defers Skill entirely, Phase 7 has no extension point to call.

## Considered Alternatives
- **A.** Skip Skill in Phase 6; design + implement Skill in Phase 7.
- **B.** Phase 6 ships a **Skill stub** with reserved protocol; Phase 7 fills body. **← Chosen.**
- **C.** Phase 6 invents a different abstraction (e.g., Behavior-as-Skill); Phase 7 must bridge.

## Decision
- Phase 6 ships a `Skill` protocol with `name`, `invoke(intent:)`, `cancel()`, and `permission` properties — all methods are stub-implemented (return identity / no-op).
- Phase 7 fills implementations and adds the MCP bridge.

## Rationale
- Phase 7 is "the real Skill Runtime"; Phase 6 exposes the contract.
- Behavior Runtime (Phase 6) calls Skills locally via the same protocol Phase 7 will call.
- Avoids Phase 7 having to retro-fit Phase 6 behavior code.

## Consequences
- (+) Phase 7 integrates without Phase 6 refactor.
- (+) Stub Skills are testable (mock implementations).
- (–) Phase 6 grows a Skill registry shape that Phase 7 may want to extend; new ADRs to amend.

## Trace
- `specs/Phase-6-Behavior/overview.md` Pre-known Deliverables (`spec-007-skill-stub.md`)
- `specs/Phase-7-AI/overview.md` Pre-known Deliverables (`spec-004-skill-runtime.md`)
- `api/skill-api.md` (stub then expand)
