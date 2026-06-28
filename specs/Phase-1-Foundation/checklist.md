# Phase 1 — Close-out Checklist

> Sprint close review. Every box must be checked before Phase 2 begins.

---

## Code & Build

- [ ] All six Phase 1 Work Specs `Status: Done`
  - [ ] `spec-001-bootstrap.md`
  - [ ] `spec-002-window.md`
  - [ ] `spec-003-runtime.md`
  - [ ] `spec-004-asset.md`
  - [ ] `spec-005-animation.md`
  - [ ] `spec-006-profiler.md`
- [ ] `swift build` succeeds
- [ ] `swift test` passes
- [ ] `xcodebuild test` passes
- [ ] No outstanding `TODO` / `FIXME` in shipped code
- [ ] All public APIs documented in api/ initial content

## Documentation

- [ ] `architecture/lifecycle.md` updated
- [ ] `architecture/threading-model.md` updated
- [ ] `architecture/module-layout.md` updated
- [ ] `architecture/desktop-overlay.md` updated
- [ ] `api/runtime-api.md` updated
- [ ] `api/window-api.md` updated
- [ ] `api/asset-api.md` updated
- [ ] `api/animation-api.md` updated
- [ ] `assets/fox-model-spec.md` updated
- [ ] `assets/glb-format-spec.md` updated
- [ ] `assets/animation-format-spec.md` updated

## Decisions / ADRs

- [ ] `decisions/D-001` written (Phase decomposition) — ✅ created 2026-06-28
- [ ] `decisions/D-002` written (TDD) — ✅ created 2026-06-28 (Accepted)
- [ ] `decisions/D-003` written (World Integration Reservation) — ✅ created 2026-06-28 (Phase 1 carries no reservation but ADR is seeded)
- [ ] `decisions/D-004` written (Skeleton + Animation embedded in .glb) — ✅ created 2026-06-28
- [ ] `decisions/D-005` written (Phase 5 split) — ✅ created 2026-06-28
- [ ] `decisions/D-007` written (Animation Driver cross-delivered by Phase 5) — ✅ created 2026-06-28
- [ ] `decisions/D-008` written (Continuous Profiling in Phase 1) — ✅ created 2026-06-28
- [ ] `decisions/D-009` written (Phase 8 → Hardening rename) — ✅ created 2026-06-28
- [ ] `decisions/D-010` written (Apple Spec style) — ✅ created 2026-06-28
- [ ] `decisions/D-011` written (Legacy 44-Spec archival policy) — ✅ created 2026-06-28
- [ ] `decisions/D-012` written (IK scope four variants) — ✅ created 2026-06-28
- [ ] `decisions/D-013` written (4-category Acceptance global rule) — ✅ created 2026-06-28
- [ ] `decisions/D-006` written (Local Behavior Runtime + Skill stub) — ✅ created 2026-06-28
- [ ] `decisions/README.md` index reflects D-001 .. D-013

## Performance Budget Snapshot (frozen baseline for Phase 2 regression)

- [ ] Cold start full bench script committed
- [ ] 60 s FPS / memory / CPU trace committed as baseline
- [ ] Profiler `.everyFrame` overhead measured and recorded

## Acceptance Sign-Off

- [ ] All 31 acceptance items in `acceptance.md` pass
- [ ] Phase 2 owner confirms readiness
- [ ] Project owner (Xavier Zhang) signs off

## Release

- [ ] Git tag `phase-1-foundation` created (do NOT push to main without explicit owner OK)
- [ ] Changelog / release note stub appended
