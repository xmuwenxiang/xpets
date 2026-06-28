<!--
Status: Draft
Phase: 8 — Hardening
-->


# SPEC-003 — GPU Budget

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.

---

## 1. Goal

Keep GPU usage under 5 % baseline in full mode. Targeted shader wins.

---

## 2. Deliverables

- Targeted wins:
  - Phase-2 PBR shader ALU ≤ 220 → ≤ 180 in RELEASE.
  - Phase-4 IK solvers: avoid redundant matrix mults.
  - Shadow PCF → variance shadow map (VSM) only if Phase-2 spec-004 Shadow is still in use.
- Tests:
  - 60 FPS × 60 s, GPU P99 ≤ 8 ms / frame.
  - Reduction in draw calls batched ≥ 20 %.

---

## 3. Out of Scope

- ❌ GPU compute spring (Phase-3 deferred item) — out.

---

## 4. Risk

- **VSM regressions** — Mitigation: opt-in only.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- GPU P99 ≤ 8 ms / frame.
- Draw call batching ≥ 20 % gain.
- Memory delta ≤ 1 MB.

### Enumerable

- 60 s stress; stable GPU time.
- VSM opt-in toggle works.

### Assertable

- Opt-in flag static.
- ALU count validated via offline Metal compiler.

### Regression

- Phase 1..7 Acceptance still pass.
