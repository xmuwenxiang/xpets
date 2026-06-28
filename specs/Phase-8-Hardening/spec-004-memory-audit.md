<!--
Status: Draft
Phase: 8 — Hardening
-->


# SPEC-004 — Memory Audit (Target: < 100 MB)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> **The flagship Phase-8 deliverable.** Brings 168 MB → < 100 MB.

---

## 1. Goal

Reclaim ≥ 68 MB via the strategies listed in `overview.md` §3. After SPEC-004 ships, `swift run` shows `footprintMBytes ≤ 100` on a fresh boot with all phases active.

---

## 2. Deliverables

- Settings via `DPFoundation.Config`:
  - `release.hdrFormat = b10a2` (default in RELEASE).
  - `release.shadow.cascadeDefault = 1 × 1024` (default in RELEASE).
  - `release.assetCache.capacityMB = 16`.
  - `release.memoryStore.walRetentionDays = 7`.
- Lazy allocation:
  - Phase-5 entity catalog truncates to 50 in RELEASE.
  - Phase-7 Skill registry uses shared singletons.
- Tests:
  - Boot memory baseline ≤ 100 MB on M2 + macos-14.
  - 60 soak minutes: peak memory ≤ 110 MB.
  - Phase-7 Privacy Spec still enforced (no Privacy boundary regression).

---

## 3. Out of Scope

- ❌ Memory-mapped files for asset streaming — out.

---

## 4. Risk

- **Pixel-format downgrade artifacts** — Mitigation: visual diff tested at 1 % MSE threshold.
- **Asset cache smaller → cold-start hit-rate drops** — Mitigation: cache hit-rate tested ≥ 70 %.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- Boot memory ≤ 100 MB.
- Peak memory ≤ 110 MB during 60-min soak.
- Visually no visible regression at 1 % MSE.

### Enumerable

- 60-min soak: peak ≤ 110 MB.
- Cache hit-rate ≥ 70 % during typical use.

### Assertable

- Each config setting has a default; release builds differ from debug.
- Privacy Spec still in force.

### Regression

- Phase 1..7 Acceptance still pass; visual diff ≤ 1 % MSE.
