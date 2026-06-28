<!--
Status: Draft
Phase: 8 — Hardening
-->


# SPEC-005 — Battery Audit

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.

---

## 1. Goal

The Pet's power draw on Apple Silicon must be ≤ the baseline "idle macOS" benchmark. Tests with `powermetrics` over 1 hour of idle activity.

---

## 2. Deliverables

- `DPHardening.BatteryAudit`:
  - `powermetrics -s gpu_power,cpu_power -i 1000` parser.
  - Reports 1-hour-soak average `mW` consumption.
  - Thresholds: GPU < 5 % of macOS idle baseline; CPU < 1 %.
- Tests:
  - 1-hour soak with Pet at full + idle → power ≤ macOS idle baseline × 1.05.

---

## 3. Out of Scope

- ❌ Cross-platform — Apple Silicon only.

---

## 4. Risk

- **`powermetrics` permissions** — Mitigation: tests skip if unavailable; threshold test flagged for CI matrix.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- Battery draw ≤ 1.05 × macOS idle baseline over 1 hour.
- Memory delta ≤ 0.5 MB.

### Enumerable

- 1-hour soak → power assertion.
- Per-frame power available via Profiler.

### Assertable

- Threshold constants static.

### Regression

- Phase 1..7 Acceptance still pass.
