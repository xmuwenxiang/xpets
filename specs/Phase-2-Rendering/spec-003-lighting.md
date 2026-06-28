<!--
Status: Draft
Phase: 2 — Rendering
Owner: TBD
Depends: Phase 2 spec-001-metal-renderer.md, spec-002-material-pbr.md
ADRs:   D-008 (Profiler budget), D-013
-->

# SPEC-003 — Lighting (Directional + IBL)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> Lighting is split into **Directional** (analytic sun) and **IBL** (image-based, environment map). Spec-003 requires both because PBR is unsaturated without IBL per the diagnostic in `00-spec-conventions.md` §3.5 PBR pitfall list.

---

## 1. Goal

Bring up direct lighting (1× Directional light producer) and indirect lighting (HDR cubemap IBL) so the PBR fox exhibits physically-realistic response: specular highlights, Fresnel rim glow on grazing angles, and (under IBL) ambient occlusion-like cavity darkening without an explicit AO pass. After SPEC-003 ships, dimming the directional light to zero still produces an IBL-lit fox — visible by specular reflections of the environment alone.

---

## 2. Deliverables

- `DPRenderer.LightingState` (per-frame uniform):
  - `directional: DirLight? = { direction, color, intensityLinear }`.
  - `environment: EnvMap? = { cubemap, intensityScale }`.
  - `exposure: Float = 1.0` (default; HDR tone mapping ownership — see `spec-005`).
- `DPRenderer.LightingPass` (concrete `RenderPass`):
  - Encodes light buffer as a small SSBO-like buffer (`MTLBuffer` of 256 bytes max for the Phase 2 budget).
  - GPU-side: lighting contribution added to PBR specular/diffuse from `spec-002`.
- IBL setup:
  - `IBLProbe.fromKernel(mipmapChain:)` — converts a cubemap + pre-filtered mips into a runtime probe.
  - Default probe = a built-in synthetic HDR gradient (sun + sky-bottom) generated at boot if no asset-side probe exists — fallback is non-null so the lighting code path is never null-checked.
- Asset integration:
  - `DPAsset.DecodedModel` (Phase 1) extended ergonomically — does NOT change signature (back-compat).
  - IBL cubemap is **not** stored in the fox GLB per D-004; comes from a separate bundled asset.
- **Tests** (TDD per D-002):
  - Unit: zero-directional light + non-null IBL → cubemap-only contribution test screenshot differs from (zero-directional + null IBL) by ≥ 5 % mean-L2.
  - Unit: directional ramp 0 → 1 → 0 leaves a visible specular highlight at the midpoint.
  - Edge: null IBL probe + zero directional → renders fully black; `LightingError.noLightsDuringIBLFallback` if strict mode asserts false.
- **API docs**: `api/lighting-api.md` — LightingState threading, IBL probe lifetime (probes are reused across frames, not rebuilt per-frame).

---

## 3. Out of Scope

- ❌ Time-of-day cycle — Phase 5b.
- ❌ Multiple Directional lights (only 1 in Phase 2) — Phase 8 if needed.
- ❌ Point / Spot lights — post-Phase 9 roadmap.
- ❌ Light culling — Phase 8.
- ❌ Shadow caster / receiver — `spec-004-shadow.md`.
- ❌ HDR Tone Mapping pipeline post-lighting — `spec-005-hdr-post.md`.

---

## 4. Risk

- **IBL cubemap wrong sRGB tag** → PBR specular wash-out — Mitigation: HDR cubemap encoded as `MTLPixelFormat.rgba16Float` (linear); test assertion of pixel format.
- **Dir-light direction drift** under window resize (camera-relative vs world-relative reference frame) — Mitigation: light direction stored as `SIMD3<Float>` relative to **world**; renderer recomputes view-projection matrix on resize.
- **IBL pre-filter mip chain at boot** runs into a memory spike — Mitigation: probe generation is async on a background `DispatchQueue`; the lighting pass waits a single frame for "ready", then continues. Graceful fallback is the synthetic gradient.
- **Directional + IBL double-counting** (additive specular too bright) — Mitigation: `LightingState` struct carries a `compositeMode: .iblOnly | .dirOnly | .additive | .screen`; default `.screen` (energy-preserving).
- **Cross-platform IBL endianness / texture orientation** — Mitigation: Apple Silicon only; macOS 14 / Metal 3.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- Lighting pass GPU time P99 over 600-frame window ≤ 1.5 ms (test extracts via Profiler).
- IB-L single-probe upload ≤ 8 ms one-time cost (measured at boot).
- CPU-side `LightingState` packing cost ≤ 50 µs / frame.

### Enumerable use case

- directional = null + environment = synthetic-gradient: cubemap-only contribution present; CIE-Lab ΔE vs reference ≤ 4.
- directional = { down, white, 1.0 } + environment = null: direct-only fan-of-light visible on fox; reference render matches.
- both non-null at intensity 1.0: composite via `.screen`; pixel histogram Y-channel max ≤ 1.0 (no additive saturation).
- Rotate DirLight direction 90° around Y: highlight on fox face follows the light direction (visual test asserts position deltas).

### Assertable state

- `LightingState` is `Sendable`; copying across Renderer thread is lock-free.
- IBL probe generation is one-shot per AssetKey; second probe request for same key returns the cached probe instance (`==`).
- `LightingError.noLightsDuringIBLFallback` only fires in `strict` mode; default boot does NOT raise this error.
- `IBLProbe` keeps `weak var` semantics on shared cubemap — `weakMTLTexture == nil` after explicit release in test.

### Previous-Phase regression

- All Phase 1 `acceptance.md` rows still pass — re-run CI.
- Phase-2 `spec-001` and `spec-002` Acceptance still pass.
- Memory delta introduced by `spec-003` ≤ 6 MB (LightingState buffer + default cubemap mips).
- Profiler `.everyFrame` overhead ≤ 0.5 ms (Phase-1 row 24) — Lighting counter emission must not regress this.
