# D-008 — Continuous Profiling Bootstrapped in Phase 1

## Status
Accepted · 2026-06-28

## Context
Performance regressions across Phases 1–7 are the leading cause of late-phase rewrites in similar Runtime projects. Profiling added late (Phase 8 / Hardening) means no baseline data exists for earlier decisions, forcing optimization to start blind. Apple, Google, and Unity all bootstrap Performance infrastructure in Phase 0.

## Considered Alternatives
- **A.** Defer Profiler to Phase 8 (Optimization/Hardening).
- **B.** Bootstrap Profiler in Phase 1; every Phase's Acceptance carries a Performance-budget line. **← Chosen.**
- **C.** Profile only in release mode, not Phase 1.

## Decision
- Phase 1 ships `DPProfiler` with Frame Pacing / GPU Time / Memory Sampler.
- Every Phase's Acceptance item includes a Performance-budget line (per D-013 Performance Metric category).
- Per-frame overhead ≤ 0.5 ms when Profiler is ON; zero allocations when OFF.

## Rationale
- Performance budget drift is visible from Sprint 1, not Sprint 8.
- AI tools see Performance constraints as a first-class spec input.
- Phase 8 becomes "closing pass" not "discovery pass".

## Consequences
- (+) Every Phase ships with metric evidence.
- (+) Hardening (Phase 8) lists concrete deltas to chase.
- (–) Phase 1 grows by one Work Spec.

## Trace
- `specs/Phase-1-Foundation/spec-006-profiler.md`
- `specs/Phase-1-Foundation/acceptance.md` §A.6
- `architecture/lifecycle.md` (Profiler slot in boot order)
