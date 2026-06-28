<!--
Status: Draft
Phase: 8 — Hardening
-->


# SPEC-002 — CPU Budget

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.

---

## 1. Goal

Bring CPU usage under sustained budget across all phases. Continuous Profiling (`D-008`) instrumentation provides the baseline.

---

## 2. Deliverables

- `DPHardening.CPUProfiler`:
  - Sample threads every 5 s; aggregate per-frame CPU.
  - Top-10 hot-path identification (Phase 2/3/4/5/6/7 modules).
- Targeted wins table (RELEASE-only):
  - Phase 5 EntityCatalog: lazy alloc.
  - Phase 3 SpringSimulation: SIMD pre-computed stiffness vectors.
  - Phase 7 IPC: zero-copy JSON parse where possible.
- Tests:
  - Stress test: 60 FPS sustained × 60 s; mean CPU ≤ 5 %, P99 ≤ 8 %.
  - Hot-path validation: top-5 hot path matches expected list.

---

## 3. Out of Scope

- ❌ Core count tuning — out.

---

## 4. Risk

- **Prof-guided changes stall edge cases** — Mitigation: keep all changes gated behind a config flag.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- Mean CPU ≤ 5 %; P99 ≤ 8 % under stress.
- Memory delta ≤ 1 MB.

### Enumerable

- 60 s stress → no frame > 16 ms.
- Top-5 hot path matches expected.

### Assertable

- Opt-in flag is `static let`.
- Top-k hot path is deterministic.

### Regression

- Phase 1..7 Acceptance still pass.
