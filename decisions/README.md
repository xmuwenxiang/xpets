# Decision Records (ADR)

> Architecture Decision Records. Each ADR captures **one** decision, the alternatives considered, the tradeoffs, and the rationale. ADRs are immutable once `Status: Accepted` — superseded ADRs remain in place, with the new ADR linking back.

---

## Format

```
D-NNN-<slug>.md

## Status
Accepted | Superseded by D-MMM | Deprecated

## Context
What situation prompted the decision.

## Considered Alternatives
A, B, C — each with one-line pros/cons.

## Decision
What we chose.

## Rationale
Why — concrete reasons, not generic platitudes.

## Consequences
What this enables / forecloses / costs.

## Trace
- roadmap ID (D-001..D-013)
- Phase(s) affected
- Specs affected
- API docs affected
```

---

## Index

| ID | Decision | Status | File |
|---|---|---|---|
| D-001 | 9-Phase milestone decomposition supersedes 44-Spec module decomposition | Accepted | `D-001-phase-decomposition.md` |
| D-002 | TDD enforced — every Work Spec ships with unit + integration tests authored test-first | Accepted | `D-002-tdd.md` |
| D-003 | World Integration Reservation required in Phase 3 + Phase 4 | Accepted | `D-003-world-reservation.md` |
| D-004 | Skeleton + Animation embedded in .glb | Accepted | `D-004-glb-embedded-animation.md` |
| D-005 | Phase 5 internal split (5a / 5b) without Phase renumbering | Accepted | `D-005-phase-5-split.md` |
| D-006 | Phase 6 = local Behavior Runtime; Skill stubbed | Accepted | `D-006-behavior-runtime.md` |
| D-007 | Phase 5 cross-delivers Animation Driver interface | Accepted | `D-007-animation-driver-cross-deliver.md` |
| D-008 | Continuous Profiling bootstrapped in Phase 1 | Accepted | `D-008-continuous-profiling.md` |
| D-009 | Phase 8 renamed to Hardening | Accepted | `D-009-phase-8-hardening.md` |
| D-010 | Apple Spec style is the only Work Spec template | Accepted | `D-010-apple-spec-style.md` |
| D-011 | Legacy 44-Spec preserved for traceability, not authoritative | Accepted | `D-011-legacy-archive-policy.md` |
| D-012 | Phase 4 IK scope fixed: Two-Bone / CCD / Foot / Look-At | Accepted | `D-012-ik-scope-quadruped.md` |
| D-013 | 4-category Acceptance global rule | Accepted | `D-013-acceptance-4-categories.md` |

---

## Status

This directory's index is **Active**. Each ADR file documents one decision. The Index must be updated atomically when a decision is added or amended.
