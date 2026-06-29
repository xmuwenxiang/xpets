# Phase 2 — Acceptance (End-to-End)

> Every Phase-2 Acceptance criterion in one place, mapped to the owning Work Spec. Used during close-out review and E2E demo scripting. 4-category form per D-013 (`00-spec-conventions.md` §3.5).
>
> **Verifier convention**: `Unit test` / `Integration test` run in CI (`macos-14`); `Local visual baseline (M4)` runs via offline frame-capture on the owner machine, recorded into this file's evidence section — **not** gated in CI (reference frames are fragile).

---

## B.1 Renderer Backbone (spec-001)

| # | Item | Category | Verifier |
|---|---|---|---|
| 1 | `Renderer.tick(_:)` CPU ≤ 4 ms @ 60 FPS with 6 Passes | Performance | Integration test |
| 2 | no-op Pass GPU P99 ≤ 0.5 ms over 600-frame window | Performance | Local visual baseline (M4) |
| 3 | Register 4 → `[root,A,B,C,D]`; unregister `B` → `[root,A,C,D]` | Enumerable | Unit test |
| 4 | Duplicate Pass ID → `RendererError.duplicatePassID`, original preserved | Enumerable | Unit test |
| 5 | `currentFrameIndex == 0` at init; +1 per tick | Assertable | Unit test |
| 6 | `MTLDevice` in-process count == 1 | Assertable | Unit test |
| 7 | Register after first tick → `RendererError.alreadyRunning` | Assertable | Unit test |
| 8 | `unregisterPass` → `weakPass == nil` after drain | Assertable | Unit test |

## B.2 PBR Material (spec-002)

| # | Item | Category | Verifier |
|---|---|---|---|
| 9 | Material re-bind ≤ 0.3 ms / draw call (same SamplerState) | Performance | Integration test |
| 10 | `MaterialPass` memory delta ≤ 6 MB on Phase-1 baseline | Performance | Integration test |
| 11 | Material index 0 vs 1 → render differs ≥ 5 % mean-L2 | Enumerable | Local visual baseline (M4) |
| 12 | AO-only material darkens cavity ≥ 2 % mean-L2 vs baseline | Enumerable | Local visual baseline (M4) |
| 13 | `Material.fromGlb(i)` pure — repeat call returns `==` | Assertable | Unit test |
| 14 | Missing channel → `MaterialError.missingChannel`; never zero-default | Assertable | Unit test |
| 15 | Texture cache `.hit` on second render of same material | Assertable | Unit test |

## B.3 Lighting (spec-003)

| # | Item | Category | Verifier |
|---|---|---|---|
| 16 | Lighting pass GPU P99 ≤ 1.5 ms over 600-frame window | Performance | Local visual baseline (M4) |
| 17 | IBL single-probe upload ≤ 8 ms one-time at boot | Performance | Integration test |
| 18 | `LightingState` packing ≤ 50 µs / frame | Performance | Integration test |
| 19 | null-dir + synthetic-IBL → cubemap-only contribution, ΔE ≤ 4 | Enumerable | Local visual baseline (M4) |
| 20 | DirLight 90° Y-rotation → highlight follows | Enumerable | Local visual baseline (M4) |
| 21 | `LightingState` `Sendable`; lock-free across Renderer thread | Assertable | Unit test |
| 22 | IBL probe one-shot per AssetKey; repeat returns cached `==` | Assertable | Unit test |
| 23 | `noLightsDuringIBLFallback` fires in strict mode only | Assertable | Unit test |

## B.4 Shadow (spec-004)

| # | Item | Category | Verifier |
|---|---|---|---|
| 24 | `ShadowPass.encode` GPU P99 ≤ 2.5 ms (2 cascade × 2048) | Performance | Local visual baseline (M4) |
| 25 | Shadow texture steady-state delta ≤ 24 MB | Performance | Integration test |
| 26 | `ContactShadowToggle.enable=true` adds zero GPU time | Performance | Unit test |
| 27 | 1 cascade × 512 → coverage ≥ 30 %; 2 × 2048 → ΔE ≤ 3; 4 × 2048 → no realloc in 60 frames | Enumerable | Local visual baseline (M4) |
| 28 | `biasMode = .adaptive` → no acne across 5 randomized light dirs | Enumerable | Local visual baseline (M4) |
| 29 | `MTLTexture.arrayLength == cascadeCount` | Assertable | Unit test |
| 30 | `cascadeCount = 0` → `ShadowError.invalidCascadeCount` at registration | Assertable | Unit test |
| 31 | `ContactShadowToggle` setters `Sendable`; zero render mutation | Assertable | Unit test |

## B.5 HDR Post (spec-005)

| # | Item | Category | Verifier |
|---|---|---|---|
| 32 | `HDRPostPass` GPU P99 ≤ 1.2 ms (incl. FXAA) | Performance | Local visual baseline (M4) |
| 33 | HDR framebuffer steady-state ≤ 32 MB (incl. Retina 2×) | Performance | Integration test |
| 34 | `BloomPass.register()` adds zero GPU time | Performance | Unit test |
| 35 | `.acesFilmic` + DirLight 1.0 → max-channel ≤ 1.0, ΔE ≤ 4 | Enumerable | Local visual baseline (M4) |
| 36 | `exposure = 0.5` vs `1.0` → ΔE ≥ 3; full vs zero intensity → luminance ratio ≥ 10× | Enumerable | Local visual baseline (M4) |
| 37 | `toneMapper` `Codable` round-trip via `DPFoundation.Config` | Assertable | Unit test |
| 38 | `BloomPass.register()` does not mutate `Renderer` pass-order list | Assertable | Unit test |
| 39 | Black scene (DirLight=0, IBL=null) → canvas max-Y == 0 | Assertable | Unit test |

## B.6 Previous-Phase Regression

| # | Item | Category | Verifier |
|---|---|---|---|
| 40 | All Phase-1 `acceptance.md` rows 1..31 still pass | Regression | CI (`swift test`) |
| 41 | Memory baseline ≤ 65 MB must not exceed 80 MB after spec-001 | Regression | Integration test |
| 42 | Cumulative Phase-2 memory ≤ 128 MB worst-case at close | Regression | Integration test |
| 43 | Profiler `.everyFrame` overhead ≤ 0.5 ms (Phase-1 row 24) re-asserted | Regression | CI (`ProfilerTests`) |

---

## Evidence (local visual baselines)

> Filled during Round 2 implementation, per spec. Each entry: fixture, command, recorded value, pass/fail. Not CI-gated.
>
> Format: `| spec | item # | command | recorded | status |`
| spec-002b | (fox visible) | `swift run --package-path desktop-pet-core desktop-pet` (interactive) + `screencapture` + pixel analysis | fox textured on overlay (137 distinct colors, 33.6% non-sea-blue pixels in 320×320 overlay — not a flat block) | local green |
