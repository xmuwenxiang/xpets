<!--
Status: Draft
Phase: 6 — Behavior
-->



# SPEC-005 — Daily Routine (Scheduler)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> Produces a believable rhythm: morning stretch, midday play, evening observe, nighttime sleep.

---

## 1. Goal

Schedule behaviors based on Time-of-day so the Pet feels persistent. After SPEC-005 ships, the Pet is observably different at 8 a.m. vs 8 p.m.

---

## 2. Deliverables

- `DPBehavior.DailyRoutine`:
  - Time-of-day buckets: morning (6-10), midday (10-14), afternoon (14-18), evening (18-22), night (22-6).
  - Bucket → preferred `Behavior` weighting table.
  - `func currentBucket() -> TimeBucket`.
- Tests:
  - Unit: at 8 a.m. → morning bucket.
  - Unit: at 3 p.m. → afternoon bucket.
  - Determinism: 1000 bucket queries within range → consistent.

---

## 3. Out of Scope

- ❌ Time-zone-aware routine — out (single zone).

---

## 4. Risk

- **Routine predictability** — Mitigation: variance injectors (e.g. debug random offset up to ±5 minutes).

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- `currentBucket()` ≤ 1 µs.
- Memory delta ≤ 0.1 MB.

### Enumerable

- 8 a.m. → morning.
- 3 p.m. → afternoon.

### Assertable

- Bucket boundaries are static constants.

### Regression

- Phase 1..5 Acceptance still pass.
