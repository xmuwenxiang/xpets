# D-010 — Apple Spec Style as the Only Template

## Status
Accepted · 2026-06-28

## Context
Spec-writing style consistency is critical for AI-coding-tool consumption (Claude Code / Cursor / Gemini CLI). Earlier drafts used ad-hoc Go-style / RFD-style sections; each Spec had a slightly different shape, making batch-prompt invocations ambiguous.

## Considered Alternatives
- **A.** Free-form Specs, per-author preference.
- **B.** Mandate Apple-internal five-section template: Goal / Deliverables / Out of Scope / Risk / Acceptance. **← Chosen.**
- **C.** Adopt Google's design-doc template.

## Decision
All Work Spec files MUST use the Apple Spec five-section template (Goal / Deliverables / Out of Scope / Risk / Acceptance), in that order, with each Acceptance item categorized per D-013.

## Rationale
- Apple/FoundationDB RFD-like specs are well-suited to AI-tool prompts.
- Five sections are mnemonic; per-Spec variance is suppressed.
- Acceptance always has a structured location.

## Consequences
- (+) Uniform prompts across AI tools.
- (+) Reviewers know exactly where to find risk and acceptance.
- (–) Five sections force every Work Spec; trivial specs feel over-template'd. (Mitigated by Spec-001 bootstrap's narrow template.)

## Trace
- `specs/00-spec-conventions.md` §3 (template), §3.2 (Deliverables), §3.5 (Acceptance)
- All Work Spec files under `specs/Phase-N-*`
