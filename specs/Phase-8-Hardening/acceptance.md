# Phase 8 — Acceptance

> Phase-8 closure Acceptance in 4-category form per D-013.

---

## A. By Work Spec

### A.1 SPEC-001 Frame Scheduler

| Category | Item |
|---|---|
| Performance | Mode transitions ≤ 100 ms |
| Performance | Idle CPU < 1 %, GPU ≤ 5 % in full mode |
| Performance | Memory delta ≤ 0.5 MB |
| Enumerable | 30 s idle → idle30 |
| Enumerable | 60 s idle → sleep |
| Enumerable | mousemove → full |
| Assertable | Threshold constants static |
| Regression | Phase 1..7 Acceptance still pass |

### A.2 SPEC-002 CPU Budget

| Category | Item |
|---|---|
| Performance | Mean CPU ≤ 5 %; P99 ≤ 8 % |
| Performance | Memory delta ≤ 1 MB |
| Enumerable | 60 s stress, no frame > 16 ms |
| Enumerable | Top-5 hot path matches expected |
| Assertable | Opt-in flag static |
| Regression | Phase 1..7 Acceptance still pass |

### A.3 SPEC-003 GPU Budget

| Category | Item |
|---|---|
| Performance | GPU P99 ≤ 8 ms / frame |
| Performance | Batch ≥ 20 % gain |
| Performance | Memory delta ≤ 1 MB |
| Enumerable | 60 s stress, stable GPU time |
| Enumerable | VSM opt-in toggle works |
| Assertable | Opt-in flag static |
| Regression | Phase 1..7 Acceptance still pass |

### A.4 SPEC-004 Memory Audit (Flagship)

| Category | Item |
|---|---|
| Performance | Boot memory ≤ 100 MB |
| Performance | Peak ≤ 110 MB during 60-min soak |
| Performance | Visual diff ≤ 1 % MSE |
| Enumerable | 60-min soak, peak ≤ 110 MB |
| Enumerable | Cache hit-rate ≥ 70 % |
| Assertable | Each release config defaults distinct from debug |
| Assertable | Privacy Spec still enforced |
| Regression | Phase 1..7 Acceptance still pass |

### A.5 SPEC-005 Battery Audit

| Category | Item |
|---|---|
| Performance | Draw ≤ 1.05 × macOS idle baseline over 1 hour |
| Performance | Memory delta ≤ 0.5 MB |
| Enumerable | 1-hour soak assertion |
| Assertable | Threshold constants static |
| Regression | Phase 1..7 Acceptance still pass |

### A.6 SPEC-006 Installer Pipeline

| Category | Item |
|---|---|
| Performance | Installer size ≤ 30 MB |
| Enumerable | CI built |
| Enumerable | Manual install → boot → wizard |
| Assertable | Codesign verified |
| Assertable | Notarization ticket stapled |
| Regression | Phase 1..7 Acceptance still pass |

---

## B. Phase-8 Cumulative Row

| Category | Item |
|---|---|
| Performance | Total runtime memory worst-case ≤ **100 MB** (target; Phase-7 168 → Phase-8 100, −68 MB) |
| Performance | Mean CPU ≤ 5 %; P99 ≤ 8 % under stress |
| Performance | GPU P99 ≤ 8 ms / frame |
| Performance | Power draw ≤ 1.05 × macOS idle baseline |
| Performance | Installer size ≤ 30 MB |
| Enumerable | All SPEC-001..SPEC-006 §5 acceptance items pass |
| Assertable | Production builds use opt-in flags distinct from debug |
| Assertable | All Phase 1..7 budgets preserved |
| Assertable | Privacy Spec still in force |
| Regression | All Phase 1..7 `acceptance.md` items still pass |

---

## C. Memory Reclamation Audit

The strategies listed in `overview.md` §3 each claim a yield. At Phase-8 closure, each is asserted in a unit test:

| Strategy | Target | Test |
|---|---|---|
| HDR b10a2 | −8 MB | `testHDR_reduces_2_bytes_per_pixel` |
| Shadow default 1×1024 | −8 MB | `testShadow_default_cascade_is_smaller` |
| IBL mip reduce by 1 | −4 MB | `testIBL_mipmap_count_reduced` |
| AssetCache 16 MB | −16 MB | `testAssetCache_capacity_is_16_MB` |
| SkinningPipeline shared | −8 MB | `testSkinning_buffers_are_shared` |
| WAL 7-day truncation | −2 MB | `testMemoryStore_wal_truncated` |
| Entity catalog at 50 | −1 MB | `testEntityCatalog_truncated_to_50` |
| Skill registry singletons | −1 MB | `testSkillRegistry_singleton_only` |
| **Sum** | **−48 MB** | |

The other ~20 MB comes from misc dedupe (Phase-2/4/5/6 lazy alloc). If reclamation falls short, Phase-8 cannot close without raising an ADR.
