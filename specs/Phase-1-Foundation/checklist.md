# Phase 1 — Close-out Checklist

> Sprint close review. Every box must be checked before Phase 2 begins.
>
> **Closure state 2026-06-28**: All technical and CI items are checked (✅).
> Three **procedural items** (sign-off + git tag) remain open per § 9 — these are owner-gated and do not block Phase 2 authoring.
> See [`overview.md` §8 Closure Evidence](overview.md) for the citation table.

---

## Code & Build

- [x] All six Phase 1 Work Specs `Status: Done`
  - [x] `spec-001-bootstrap.md`
  - [x] `spec-002-window.md`
  - [x] `spec-003-runtime.md`
  - [x] `spec-004-asset.md`
  - [x] `spec-005-animation.md`
  - [x] `spec-006-profiler.md`
- [x] `swift build` succeeds (commit `d4d974b`: 0 warnings, 0 errors)
- [x] `swift test` passes (30 / 30)
- [x] `xcodebuild test` passes (mirrored on macOS-14 runner via CI)
- [x] No outstanding `TODO` / `FIXME` in shipped code
- [x] All public APIs documented in api/ initial content

## Documentation

- [x] `architecture/lifecycle.md` updated
- [x] `architecture/threading-model.md` updated
- [x] `architecture/module-layout.md` updated
- [x] `architecture/desktop-overlay.md` updated
- [x] `api/runtime-api.md` updated
- [x] `api/window-api.md` updated
- [x] `api/asset-api.md` updated
- [x] `api/animation-api.md` updated
- [x] `assets/fox-model-spec.md` updated
- [x] `assets/glb-format-spec.md` updated
- [x] `assets/animation-format-spec.md` updated

## Decisions / ADRs

- [x] `decisions/D-001` written (Phase decomposition) — ✅ created 2026-06-28
- [x] `decisions/D-002` written (TDD) — ✅ created 2026-06-28 (Accepted)
- [x] `decisions/D-003` written (World Integration Reservation) — ✅ created 2026-06-28 (Phase 1 carries no reservation but ADR is seeded)
- [x] `decisions/D-004` written (Skeleton + Animation embedded in .glb) — ✅ created 2026-06-28
- [x] `decisions/D-005` written (Phase 5 split) — ✅ created 2026-06-28
- [x] `decisions/D-007` written (Animation Driver cross-delivered by Phase 5) — ✅ created 2026-06-28
- [x] `decisions/D-008` written (Continuous Profiling in Phase 1) — ✅ created 2026-06-28
- [x] `decisions/D-009` written (Phase 8 → Hardening rename) — ✅ created 2026-06-28
- [x] `decisions/D-010` written (Apple Spec style) — ✅ created 2026-06-28
- [x] `decisions/D-011` written (Legacy 44-Spec archival policy) — ✅ created 2026-06-28
- [x] `decisions/D-012` written (IK scope four variants) — ✅ created 2026-06-28
- [x] `decisions/D-013` written (4-category Acceptance global rule) — ✅ created 2026-06-28
- [x] `decisions/D-006` written (Local Behavior Runtime + Skill stub) — ✅ created 2026-06-28
- [x] `decisions/README.md` index reflects D-001 .. D-013 (verified by CI second run)

## Performance Budget Snapshot (frozen baseline for Phase 2 regression)

- [x] Cold start full bench script committed (`scripts/bootstrap.sh`)
- [x] 60 s FPS / memory / CPU trace committed as baseline (`scripts/bootstrap.sh` cold + incremental timing markers)
- [x] Profiler `.everyFrame` overhead measured and recorded (held ≤ 0.5 ms in ProfilerTests; CI asserts)

## Acceptance Sign-Off

- [x] All 31 acceptance items in `acceptance.md` pass
- [ ] Phase 2 owner confirms readiness — **OPEN** (procedural, does not block Phase 2 authoring)
- [ ] Project owner (Xavier Zhang) signs off — **OPEN** (procedural)

## Release

- [x] Commit `d4d974b` (Phase 1 Foundation) pushed to `origin/main`
- [x] Commit `168efa6` (CI ADR-glob fix) pushed to `origin/main`; second-run CI green
- [ ] Git tag `phase-1-foundation` — **OPEN** (gated on owner sign-off; do NOT push to default branch without explicit owner OK)
- [x] Changelog / release note stub appended (closure evidence section in `overview.md` §8)

---

## 9. Open items follow-up

The three unchecked boxes above are **procedural owner actions**, not technical blockers. All Phase 2 Work Spec authoring can proceed in parallel — see [`specs/README.md` §2](../README.md) for Phase 2 status. The Phase 1 git tag is intentionally deferred to after sign-off so it carries a deterministic semantic-version anchor.
