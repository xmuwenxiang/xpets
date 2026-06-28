<!--
Status: Draft
Phase: 4 — Animation
Owner: TBD
Depends: Phase 1 spec-005-animation.md
-->

# SPEC-003 — Random Idle Picker

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> The fox should not be visibly looping. Random Idle picks among N subtle idle clips so the idle pose feels alive (Disney-Physics "secondary motion" ally).

---

## 1. Goal

Provide a deterministic-but-varied random selection over a curated Idle clip pool so the fox appears to have personality during indefinite stand-still phases. After SPEC-003 ships, the fox idle state visibly differs across 30 seconds of observation at least 6 times (≥ 20 % entropy sample rate), without ever repeating the same clip within a 100 ms correlation window.

---

## 2. Deliverables

- `DPAnimation.RandomIdlePicker`:
  - Factory `init?(idlePoolName: String, count: Int = 8)`.
  - The idle pool is supplied via Phase-1 `DPAsset` (clip indexing); the picker only knows the pool name + indices.
  - `nextClip(seed: UInt64) -> AnimationClip.ID` — deterministic; same seed → same pick sequence.
  - `nextClipForRealTime()` — uses `CFAbsoluteTimeGetCurrent()` as default seed; no caller seed needed.
- Entropy window: 100 ms correlation window — picker avoids the same clip as the previous pick if `dt < 100 ms`.
- Tests:
  - Unit: same `seed` over 1000 picks produces deterministic order — assertable via first-100-bit sequence equality.
  - Unit: 30 simulated seconds of picker activity yields ≥ 6 distinct picks (entropy target).
  - Unit: 100 ms correlation enforcement — feeding `dt = 50 ms` repeatedly never preserves the previous pick.
- **API docs**: `api/random-idle-api.md` — seed policy, correlation-window contract.

---

## 3. Out of Scope

- ❌ Decision / Emotion influence on idle choice — Phase 6.
- ❌ Behavior / mood-based picking — Phase 6.
- ❌ Cross-clip blending (a Transition between idles is handled by BlendTree `spec-001`).
- ❌ Multi-track idle — Phase 6.

---

## 4. Risk

- **Pool starvation** when count is too low — Mitigation: count must be ≥ 2, ≤ 32; preload validation test asserts.
- **Visual coherence loss** with random pick — Mitigation: pool is curated by hand; Phase-1 spec-005 already documents the chosen-pose constraints.
- **Seed reproducibility drift** between Swift versions — Mitigation: PRNG is `SystemRandomNumberGenerator`-derived, **but** the deterministic test uses a hand-coded `SplitMix64` to keep platform-stable.
- **Correlation window false-positive** under uneven tick — Mitigation: window based on real-time `CFAbsoluteTime`, not on `tick(dt:)` accumulator.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- `nextClip(seed:)` ≤ 5 µs / call on M2.
- Memory delta ≤ 0.5 MB on top of Phase-4 spec-001.
- Profiler budget unchanged.

### Enumerable use case

- 1000 calls with `seed = 42` → first 16 picks reproducible; full sequence stable across re-runs.
- 30 simulated real-time seconds → ≥ 6 distinct picks (entropy target).
- 100 ms correlation enforced: caller drives `nextClipForRealTime()` every 50 ms — same pick never returned twice.

### Assertable state

- `RandomIdlePicker.init` refuses `count = 0` and `count > 32` — assertable.
- The deterministic seed policy uses `SplitMix64` — assertable by signature in code test.
- `idempotent` across migration (Phase 5 forward-compatible) — pool name ref stable.

### Previous-Phase regression

- Phase 1 + Phase 2 + Phase 3 + Phase-4 `spec-001..002` Acceptance still pass.
- Phase-1 `AnimationClip` machinery unchanged.
- Profiler `.everyFrame` overhead unchanged.
