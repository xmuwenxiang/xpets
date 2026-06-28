<!--
Status: Draft
Phase: 6 — Behavior
-->



# SPEC-002 — Utility AI (Behavior Scoring)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> The scoring engine that picks the next Behavior the Pet performs. Pure functional — same inputs → same output.

---

## 1. Goal

Score behaviors (Sleep / Eat / Play / Observe / Talk / Explore) based on Emotion (Energy / Curiosity / Trust / Happiness), current Time-of-day, and Recent Memory. Pick the highest-scoring behavior. Output is a `BehaviorDecision` containing the chosen behavior and parameters.

After SPEC-002 ships, the Behavior Runtime invokes Utility AI every `decide` cycle; misfires are not visible (the pet does not stutter between Behaviors).

---

## 2. Deliverables

- `DPBehavior.Behavior` enum:
  - `.sleep`, `.eat`, `.play`, `.observe`, `.talk`, `.explore`.
- `DPBehavior.BehaviorDecision`:
  - `behavior: Behavior`, `parameters: [String: AnyCodable]`, `score: Float`.
- `DPBehavior.UtilityAI`:
  - `func next(Emotion, TimeOfDay, Memory) -> BehaviorDecision`.
  - Pure function — no side effects; deterministic.
- Tests:
  - Unit: at high Energy + low Curiosity + daytime → `explore`.
  - Unit: at low Energy + nighttime → `sleep`.
  - Determinism: 1000 calls with same inputs → identical outputs (FP-bit exact).
  - Tie-breaker: when two behaviors tie → deterministic ordering (lexicographic on `Behavior`).

---

## 3. Out of Scope

- ❌ Behavior implementations — split between Phase 4 (animation) and Phase 7 (Skills).
- ❌ Emotion state — `spec-003-emotion.md`.

---

## 4. Risk

- **Behavior explosion** — Mitigation: 6 base behaviors only; new ones via Skill invocation.
- **Score unstableness** — Mitigation: scores clamped to [0, 1]; tie-breaker is well-defined.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- `UtilityAI.next(...)` P99 ≤ 0.2 ms.
- Memory delta ≤ 0.5 MB.
- Profiler budget unchanged.

### Enumerable

- High-energy + low-curiosity + daytime → `explore`.
- Low-energy + nighttime → `sleep`.
- 1000 deterministic calls, FP-bit exact identity.

### Assertable

- `UtilityAI.next` is `Sendable`-safe.
- 1000 calls → same output hash.

### Regression

- Phase 1..5 Acceptance still pass.
