<!--
Status: Drafts authored (2026-06-28)
Phase: 8 — Hardening
Owner: TBD
ADRs:  D-008 (Continuous Profiling baseline), D-009 (Phase → Hardening rename), D-013
-->

# Phase 8 — Hardening

> **Status**: Stub → **Drafts authored (2026-06-28)**. Six Work Specs now exist at Apple Style + 4-category Acceptance; implementation gated on owner review + `Status: Approved`.
> **Goal**: Polish every system for production safety. CPU / GPU / Battery / Memory budgets become primary; Installer & distribution sizing honored.
> **Primary Output**: Runtime ≤ 100 MB, Installer ≤ 30 MB.

> **Renamed from "Optimization"** per **D-009**. Continuous Profiling was bootstrapped in Phase 1 (D-008) so this phase becomes a closing pass, not a rewriting pass.

---

## 1. Goal (Phase 8 final)

The pet is production-grade: 60 FPS sustained with full Phase 1–7 capabilities on, idle CPU < 1 %, GPU ≤ 5 %, battery draw competitive with idle macOS, memory footprint pinned at < 100 MB, installer at < 30 MB.

After Phase 8 closes, all Phase-1..7 budgets hold under stress; an opt-in Production Build profile is documented; the installer is signed + notarized.

---

## 2. Pre-known Deliverables (finalized)

- [`spec-001-frame-scheduler.md`](spec-001-frame-scheduler.md) — 60 / 30 / Idle / Sleep frame-scheduling.
- [`spec-002-cpu-budget.md`](spec-002-cpu-budget.md) — CPU profiling-driven wins.
- [`spec-003-gpu-budget.md`](spec-003-gpu-budget.md) — GPU profiling-driven wins.
- [`spec-004-memory-audit.md`](spec-004-memory-audit.md) — Resident memory sweep (target: bring 168 MB → < 100 MB).
- [`spec-005-battery-audit.md`](spec-005-battery-audit.md) — Power-log analysis.
- [`spec-006-installer-pipeline.md`](spec-006-installer-pipeline.md) — DMG / signed / notarized.

---

## 3. Memory Reclamation Plan

Phase-7 worst-case ≈ 168 MB; target < 100 MB ⇒ reclaim ~70 MB. Strategies ordered by expected yield:

| Strategy | Expected Yield |
|---|---|
| HDR framebuffer from `rgba16Float` → `rgba11Float` (HDR `b10a2`) | -8 MB |
| Shadow cascade texture 2 cascades × 2048 → 1 cascade × 1024 default | -8 MB |
| IBL cubemap mips: reduce by 1 level | -4 MB |
| MemoryCache: 32 MB → 16 MB (Phase-1 spec-004) | -16 MB |
| Animation buffers → GPU SkinningPipeline shared buffer | -8 MB |
| MemoryStore WAL truncation at 7 days | -2 MB |
| Phase-5 entity catalog truncation (in-memory 100 → 50) | -1 MB |
| Phase-7 Skill registry → shared singletons | -1 MB |
| Misc dedupe & lazy alloc (Phase-2/4/5/6 lazy alloc) | remaining |
| **Total target** | **≥ 68 MB** |

These are *targets*, not commitments. Implementation confirms at Phase-8 closure.

---

## 4. Out of Scope (Phase 8)

- ❌ New features — Phase 9+.
- ❌ Multi-Pet cohabitation — out.
- ❌ Vision Pro / AR — out.
- ❌ Custom user-authored Skills — Phase 9 Marketplace.

---

## 5. Risk

- **Reclamation aggressiveness** could destabilize behavior — Mitigation: each strategy is opt-in via `DPFoundation.Config`, default off in `DEBUG`, on in `RELEASE`.
- **Signing / notarization blocking** — Mitigation: documented in `spec-006-installer-pipeline.md` with Apple Developer ID hooks.
- **GPU budget overcorrection** — Mitigation: Phase-8 P99 stays in `Profiler.Counter` so regressions are observable.
- **Compile-time STRIP / dSYM bloat** — Mitigation: the Profiler aggregator emits release-mode metrics that omit debug symbols.

---

## 6. Acceptance (placeholder — 4-category form finalized in `acceptance.md`)

See [`acceptance.md`](acceptance.md). Cumulative Phase-8 memory delta: **−68 MB** target. Profiler `.everyFrame` overhead ≤ 0.5 ms / frame preserved. CI: green.

---

## 7. Cross-References

- **Phase 1**: `spec-006-profiler.md` (the baseline Profiler reads).
- **Phase 2..7**: every Work Spec's Performance metric row is the regression target.
- **ADRs**: D-008, D-009, D-013.
