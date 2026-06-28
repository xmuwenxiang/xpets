# D-005 — Phase 5 Internal Split (5a / 5b) Without Renumbering

## Status
Accepted · 2026-06-28

## Context
Phase 5 (Desktop World) requires two qualitatively different deliverables: (a) Desktop Entity Discovery (catalog, abstraction, privacy visibility policy, rendering-route decision) and (b) Desktop World container, NavMesh, collision, Pet interaction. They differ in input risk (Accessibility API grant, WindowList snapshot staleness) and in team composition.

## Considered Alternatives
- **A.** One Phase 5, two halves merged. Risk: tightly coupled Sprint boundary; can't ship 5a first.
- **B.** Phase 5 split with the directory remaining `Phase-5-DesktopWorld/`; sub-identifiers 5a / 5b are internal-only. **← Chosen.**
- **C.** Renumber Phase 5 → 5a and supersede Shift 5b → 6.

## Decision
- Phase directory is `specs/Phase-5-DesktopWorld/` — no renumber.
- Sub-Phase identifiers (5a, 5b) appear only in Work Spec filenames and overview headers.
- All cross-references use Phase 5; sub-Phase is implementation detail.

## Rationale
- Avoids renumber blast radius across Phase 5, 6, 7, 8, 9.
- Allows roadmap.md to refer to "Phase 5" while implementation details carry 5a/5b.
- 5a is the dependency boundary; 5b uses 5a output.

## Consequences
- (+) Roadmap stays compact (9 Phases).
- (–) `roadmap.md` must explicitly call out 5a / 5b in its Goal table.

## Trace
- `roadmap.md` §1, §2 (Phase 5 row)
- `specs/Phase-5-DesktopWorld/overview.md`
- `api/README.md` `desktop-world-api.md` row
