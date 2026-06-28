<!--
Status: Draft
Phase: 4 — Animation
Owner: TBD
Depends: Phase 1 spec-005-animation.md (Channel / Skeleton / Sampling)
-->

# SPEC-001 — BlendTree (CrossFade / Blend1D / Blend2D / Layer)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> BlendTree is the state-graph that drives which clips play, how they cross-fade, blend by parameter, blend by 2D input, and stack as Layers. Built on top of Phase-1 `Animator` + `AnimationClip`.

---

## 1. Goal

Provide a small BlendTree runtime capable of CrossFade transitions, parameter-driven Blend1D, parameter-driven Blend2D, and stackable animation Layers. The BlendTree is bounded in node count so renders stay within Profiler budget.

After SPEC-001 ships, an asset-side graph can express "Walk → Run if speed > 0.6, Idle if speed < 0.1; Layer `Ear-Twitch` overlays 5 % on top of the base clip" without manual coding per state machine.

---

## 2. Deliverables

- `DPAnimation.BlendGraph`:
  - Nodes: `CrossFade`, `Blend1D(name: parameter)`, `Blend2D(nameX:, nameY:)`, `Layer`, `State(name:)`.
  - Edge-types: `Transition(from:, to:, threshold:, blendDuration:)`.
  - Hard cap: node count ≤ 64 (configurable per-asset; default **64**, linter refuses import if exceeded).
- `DPAnimation.BlendRuntime`:
  - `tick(dt:)`, blended-pose output, parameter-list input.
  - One cross-fade per tick per state transition.
- Phase-1 `Animator.tick(dt:)` reads the `BlendRuntime` and applies the resulting pose to Bone matrices.
- Tests:
  - Unit: CrossFade `A → B` over 0.5 s at 60 FPS — final pose is exactly B within 1e-4 sample noise.
  - Unit: Blend1D with parameter `speed` ∈ [0, 1] — pose interpolates linearly between (speed=0, Idle) and (speed=1, Run).
  - Unit: Blend2D graph with `, , , , , ; ` 5-by-5 sample grid → pose at center blends 4 neighbors (assertable via `Sampling.sample(weight)`).
  - Unit: Layer on top of base — final pose = (1-α) × base + α × layer where α = 0.05 — assertable within 0.1 % tolerance.
  - Lint: BlendGraph with 65 nodes → SwiftPM test refuses to import; assertable.
- Inherits Phase-1 behavior: deterministic time-linear interpolation (per `Sampling.sample` in `DPAnimation`).
- **API docs**: `api/blendtree-api.md` — graph serialization (DOT-like), parameter protocol, runtime tick ordering.

---

## 3. Out of Scope

- ❌ IK graph nodes — `spec-002-ik-four-variants.md`.
- ❌ AnimationDriver hook — `spec-004-animation-driver.md`.
- ❌ Behavior, Emotion, Skip — Phase 6.
- ❌ Pose mirroring / negative-space passes — out.

---

## 4. Risk

- **Cross-fade duration inferred by tick gating** — Mitigation: cross-fade is intern-block-precise; we use `BlendRuntime.state.fadeProgress += dt / fadeDuration`.
- **2D blend sample precision** on small grids — Mitigation: sample is `(1−x)(1−y) p00 + (x)(1−y) p10 + …` bilinear; test asserts sum of weights = 1.0 per sample.
- **Layer mask blur** at high α — Mitigation: α clamped to [0, 1]; additive layers depend on Layer's `blendOp` enum.
- **State explosion** under asset edits — Mitigation: node-count cap; linter refuses import.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- `BlendRuntime.tick(dt:)` CPU-cost P99 ≤ 0.4 ms at 60 FPS for a 32-node graph (`Blend1D + CrossFade + Layer`).
- Memory delta ≤ 2 MB on top of Phase-3 baseline.
- Profiler `.everyFrame` overhead remains ≤ 0.5 ms / frame.

### Enumerable use case

- Walk → Run at speed transition 0.5 → 0.7 over 0.5 s: pose at exactly t=0.5 s is Run (within 1e-4 noise).
- Idle + Layer (α=0.05) for 60 frames: pose = 95 % Idle + 5 % Ear-twitch.
- 5×5 Blend2D sample at center (0.5, 0.5) with neighbors [P00, P10, P01, P11] each contributing `(1-x)(1-y)`, `(x)(1-y)`, `(1-x)(y)`, `(x)(y)` weights sum to exactly 1.0; final pose interpolates accordingly.

### Assertable state

- `BlendGraph` is `Codable` and round-trip stable — assertable.
- Linter test asserts: a 65-node graph triggers an error `BlendGraphError.nodeCountExceeded` at import time.
- Layer additive blend op produces sum, multiplicative produces product (assertable).
- `BlendRuntime.poseOutput` is `Sendable` for cross-thread consumption in tests.

### Previous-Phase regression

- Phase 1 + Phase 2 + Phase 3 `acceptance.md` items still pass.
- `Animator` Phase-1 test still passes — BlendTree wraps `Animator.tick(dt:)` rather than replacing it.
- Phase-1 channel/Sampling unchanged; this spec does not touch `Sampling` semantics.
