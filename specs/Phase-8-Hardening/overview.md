# Phase 8 — Hardening

> **Status**: Stub — Phase 7 closure gating begins content authoring.
> **Goal**: Polish every system for production safety. CPU / GPU / Battery / Memory budgets become primary; Installer & distribution sizing honored.
> **Primary Output**: Runtime ≤ 100 MB, Installer ≤ 30 MB.

> **Renamed from "Optimization"** per **D-009**. Continuous Profiling was bootstrapped in Phase 1 (D-008) so this phase becomes a closing pass, not a rewriting pass.

> ⚠️ **PLACEHOLDER — content authoring begins when Phase 7 closes.** Acceptance prose below is rewritten in 4-category form (D-013) at Phase 8 start.

---

## Goal (Phase 8 final)

The pet is production-grade: 60 FPS sustained with full Phase 1–7 capabilities on, idle CPU < 1 %, GPU ≤ 5 %, battery draw competitive with idle macOS, memory footprint pinned at < 100 MB, installer at < 30 MB.

---

## Pre-known Deliverables (to be expanded)

- `spec-001-frame-scheduler.md` — 60 / 30 / Idle Mode / Sleep Mode scheduling
- `spec-002-cpu-budget.md` — CPU profiling-driven wins
- `spec-003-gpu-budget.md` — GPU profiling-driven wins
- `spec-004-memory-audit.md` — Resident memory sweep
- `spec-005-battery-audit.md` — Power log analysis
- `spec-006-installer-pipeline.md` — DMG / signed / notarized
- `spec-007-debug-panel.md` — Full Debug Panel (replaces Phase 1 stub)

---

## Out of Scope (Phase 8)

- ❌ New features — all features must be Phase 1–7 only
- ❌ Cross-platform — Apple Silicon only
- ❌ Auto Update — Phase 9

---

## Risk (placeholder)

- GPU profiling identifying unbounded draw calls
- Memory fragmentation during long runtime (24 h test)
- Battery cost when "Always Listening" or "Always Watching" features attempted (NOT planned per Privacy Spec)

---

## Acceptance (placeholder — 4 categories)

- Full Phase 1–7 enabled → 60 FPS sustained 5 min, P99 ≤ 18 ms
- Memory ceiling ≤ 100 MB over 24 h soak
- Battery draw ≤ baseline macOS idle + 5 % on M-series laptop
- DMG signed + notarized; install size ≤ 30 MB

---

## Cross-References

- Phase 1 Profiler surface used as canonical input
- Phase 9 Telemetry may audit post-install behavior
