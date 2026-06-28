<!--
Status: Draft
Phase: 6 — Behavior
-->



# SPEC-003 — Emotion (Mood / Energy / Curiosity / Trust / Happiness)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> Emotion is a Perlin-noise-smoothed 4-vector. Drives Utility AI and Animation Layer.

---

## 1. Goal

Track the fox's 4-channel emotional state over time. After SPEC-003 ships, every emotion channel updates at most 1 Hz with bounded rate-of-change, persists across restarts, and is typed.

---

## 2. Deliverables

- `DPBehavior.Emotion` struct:
  - `energy: Float ∈ [0, 1]`
  - `curiosity: Float ∈ [0, 1]`
  - `trust: Float ∈ [0, 1]`
  - `happiness: Float ∈ [0, 1]`
- `DPBehavior.EmotionEngine`:
  - `load(persisted: Emotion)` — `_initial state`.
  - `tick(dt, interactions: [Interaction])` — update each channel per bounded rules.
  - Persistence: serialize to `DPFoundation.Config` on shift end.
- Bounded rates:
  - `|Δ energy| ≤ 0.05 / minute, floored at 0.1`.
  - Similar for other channels (rate table is a `static let`).
- Tests:
  - Unit: 60 ticks at 60 FPS with no interactions → energy decays 0.5 → 0.45 within 1 minute.
  - Unit: positive interaction `+0.1 happiness` → channel moves up by 0.1 in next tick.
  - Persistence: emotion struct round-trips through `Codable`.

---

## 3. Out of Scope

- ❌ Interaction sources — `spec-004-memory.md`.

---

## 4. Risk

- **Emotion drift causing oscillation** — Mitigation: rates hard-bounded; tests assert linearity.
- **Persistence race** — Mitigation: only `shutdown` writes to disk.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- `EmotionEngine.tick` P99 ≤ 0.1 ms.
- Memory delta ≤ 0.5 MB.
- Profiler budget unchanged.

### Enumerable

- 60-frame tick with no interactions → energy decays by 0.05.
- +0.1 happiness → moves up by 0.1 next tick.

### Assertable

- Rate bounds are `static let`.
- Codable round-trip stable.

### Regression

- Phase 1..5 Acceptance still pass.
