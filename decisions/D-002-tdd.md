# D-002 — TDD Enforced

## Status
Accepted · 2026-06-28

## Context
A long-running Runtime project accumulates regressions fast. Without binding test discipline, Phase close-out criteria rot. Earlier drafts of the Spec made `Tests authored` optional within Deliverables.

## Considered Alternatives
- **A.** Tests recommended, not mandatory.
- **B.** Tests authored test-first (TDD) — every Work Spec ships source under test. **← Chosen.**
- **C.** Tests only on PR-merge; no test-first requirement.

## Decision
Every Work Spec **MUST** ship tests authored **before** the implementation code (TDD). The transition `Approved → Implementing` is only valid once at least one failing test exists for the first Deliverable item.

## Rationale
- Acceptance criteria (D-013) are objectively measurable — TDD guarantees a regression baseline.
- Prevents "tests after" rationalization where untested code claims acceptance.
- Lets AI coding tools follow a single loop: red → green → refactor.

## Consequences
- (+) Every Work Spec has an objective regression gate.
- (+) Spec-driven development gets auditable traces (commit = test + impl).
- (–) Slower initial velocity per Spec (~30 % overhead vs test-after).

## Trace
- `specs/00-spec-conventions.md` §3.2 (Deliverables bullet) and §7 (Status Tags)
- All Work Specs under `specs/Phase-N-*`
