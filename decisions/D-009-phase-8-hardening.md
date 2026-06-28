# D-009 — Phase 8 Renamed to "Hardening"

## Status
Accepted · 2026-06-28

## Context
The legacy v1 plan (SPEC-040 / SPEC-041 / SPEC-042) grouped Phase 14 as "Performance". The v2 plan inherited "Optimization" as the working name. Once D-008 (Continuous Profiling in Phase 1) takes effect, Phase 8 is no longer "discover-and-fix" but "consolidate-and-verify" — i.e., production hardening, not first-pass optimization.

## Considered Alternatives
- **A.** Keep "Optimization" name. Mislead: Phase 8 looks like rewrites; baseline comes from Phase 1 Profiler.
- **B.** Rename to "Hardening" — clarifies it's a pass that closes existing budgets, not rewriting. **← Chosen.**

## Decision
The Phase 8 directory is renamed `Phase-8-Hardening/`; overview header reads `Phase 8 — Hardening`. The legacy name "Optimization" is reserved as a synonym only in the ADR text.

## Rationale
- Aligns with industry terminology (release hardening).
- Removes confusion between Profiling (Phase 1) and Optimization (Phase 8).

## Consequences
- (+) Clearer naming for newcomers.
- (–) Renaming after the fact requires care in legacy file references (resolved in `migration-map.md`).

## Trace
- `specs/Phase-8-Hardening/overview.md`
- `roadmap.md` §2 (Phase 8 row) and §3 (D-009 entry)
- `specs/_legacy/migration-map.md` (PRESERVES "Optimization" as legacy alias row)
