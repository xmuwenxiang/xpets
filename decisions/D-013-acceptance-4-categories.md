# D-013 — 4-Category Acceptance Global Rule

## Status
Accepted · 2026-06-28

## Context
Acceptance in early-draft Specs drifted: subjective language ("looks good"), missing categories, partial coverage. AI coding tools and human reviewers could not decide if a Spec was done. Apple and Unity both enforce machine-checkable acceptance on every Sprint; this project needs the same.

## Considered Alternatives
- **A.** Free-form acceptance. Subjective drift.
- **B.** Four mandatory categories per Acceptance block: Performance metric / Enumerable use case / Assertable state / Previous-Phase regression. **← Chosen.**
- **C.** Add a fifth "User-observable" category — excluded for redundancy with Enumerable/Assertable.

## Decision
Every Work Spec Acceptance block MUST be partitioned into four categories. Each Acceptance item MUST fall into at least one. Each item MUST be objectively measurable (numeric, boolean, or path-based — no subjective language).

## Rationale
- Forces authors to think of measurable evidence for each Spec close.
- Reviewers share a structural shell.
- AI tools get a consistent input shape.

## Consequences
- (+) Acceptance becomes a regression test in prose form.
- (+) Phase close-outs are auditable.
- (–) Each Spec carries an Acceptance cost. (Mitigated: 4-category buckets reduce re-work later.)

## Trace
- `specs/00-spec-conventions.md` §3.5
- `specs/Phase-1-Foundation/overview.md` §6 (full Phase acceptance template)
- `specs/Phase-N-*/overview.md` (all Phase overviews carry 4-category acceptance when Phase authoring completes)
