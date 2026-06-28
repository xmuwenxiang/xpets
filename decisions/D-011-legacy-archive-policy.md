# D-011 — Legacy 44-Spec Preserved as Historical Artifact

## Status
Accepted · 2026-06-28

## Context
The legacy 44-Spec plan (`specs/_legacy/specs-v1-44-spec-DEPRECATED.md`) records real prior work (see `architecture/v1-design.md`). Deleting it loses traceability and confuses readers who joined the project at v1. Conversely, leaving it as a top-level reference risks re-use of outdated assumptions as authoritative.

## Considered Alternatives
- **A.** Delete the legacy file.
- **B.** Move to `specs/_legacy/` with a DEPRECATED header; add a `migration-map.md` mapping; reference it once from `roadmap.md` §1. **← Chosen.**
- **C.** Keep as primary doc; ignore D-001.

## Decision
- Legacy file lives at `specs/_legacy/specs-v1-44-spec-DEPRECATED.md` with a DEPRECATED header pointing to v2 Phases.
- A `specs/_legacy/migration-map.md` maps each legacy SPEC-NNN to a v2 Phase destination.
- The legacy file is not authoritative. Any PR referencing SPEC-NNN must use the migration map.

## Rationale
- Preserves audit trail.
- Prevents re-use of stale assumptions.
- Explicit DEPRECATED header is honor-system + lintable.

## Consequences
- (+) History is preserved.
- (+) Future slicing of v1 work is possible.
- (–) Extra file in the tree.

## Trace
- `specs/_legacy/specs-v1-44-spec-DEPRECATED.md` (DEPRECATED header)
- `specs/_legacy/migration-map.md`
- `roadmap.md` §6 (Milestone Mapping)
