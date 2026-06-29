# Phase 2 — Close-out Checklist

> Sprint close review. Every box must be checked before Phase 3 begins.
>
> **Closure state 2026-06-29 (Round 1 review)**: 5 Work Specs promoted to `Status: Approved`; TBD/placeholder cleared; `acceptance.md` + `checklist.md` created. Implementation (Round 2) pending — Code & Build boxes remain unchecked until each spec reaches `Done`.

---

## Spec & Review (Round 1 — complete)

- [x] All five Work Specs `Status: Approved` (owner-reviewed 2026-06-29)
- [x] No `TBD` / `placeholder — to be expanded` in canonical specs (`scripts/phase2-spec-lint.sh` PASS)
- [x] `overview.md` §Acceptance rewritten in 4-category form (D-013)
- [x] `acceptance.md` created (43-row 4-category table)
- [x] `checklist.md` created
- [x] `execution-plan.md` committed (`539343d`)

## Code & Build (Round 2 — per spec)

- [ ] `spec-001-metal-renderer.md` `Status: Done`; logic tests green
- [ ] `spec-002-material-pbr.md` `Status: Done`; logic tests green
- [ ] `spec-003-lighting.md` `Status: Done`; logic tests green
- [ ] `spec-004-shadow.md` `Status: Done`; logic tests green
- [ ] `spec-005-hdr-post.md` `Status: Done`; logic tests green
- [ ] `swift build` 0 warnings / 0 errors
- [ ] `swift test` passes (Phase 1 + Phase 2 logic tests)
- [ ] Local visual baselines recorded in `acceptance.md` Evidence section

## Performance Budget (Round 2 — at close)

- [ ] Cumulative Phase-2 memory ≤ 128 MB worst-case
- [ ] Profiler `.everyFrame` overhead ≤ 0.5 ms (Phase-1 row 24) not regressed
- [ ] Per-spec GPU P99 baselines recorded (no-op ≤ 0.5 ms; Lighting ≤ 1.5 ms; Shadow ≤ 2.5 ms; HDR ≤ 1.2 ms)

## Documentation (Round 2 — at close)

- [ ] `api/renderer-api.md` updated
- [ ] `api/material-api.md` updated
- [ ] `api/lighting-api.md` updated
- [ ] `api/shadow-api.md` updated
- [ ] `api/hdr-api.md` updated

## Acceptance Sign-Off (Round 2 — at close)

- [ ] All 43 `acceptance.md` rows pass
- [ ] Phase 3 owner confirms readiness
- [ ] Project owner (Xavier Zhang) signs off

## Release (Round 2 — at close)

- [ ] Closure commit pushed to `origin/main`
- [ ] CI green (incl. `phase2-spec-lint` step)
- [ ] Git tag `phase-2-rendering` (gated on owner sign-off)
