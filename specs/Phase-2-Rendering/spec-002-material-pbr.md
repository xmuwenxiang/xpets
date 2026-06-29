<!--
Status: Approved
Phase: 2 — Rendering
Owner: Xavier Zhang
Depends: Phase 2 spec-001-metal-renderer.md, Phase 1 spec-004-asset.md (GLB decoder)
ADRs:   D-004 (Skeleton + Animation embedded in .glb), D-008 (Profiler budget), D-013
-->

# SPEC-002 — PBR Material Pipeline

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> Replaces the Phase-1 implicit `color` (mono-tone) draw with physical material evaluation. Material texture slots are read out of the Phase-1 GLB decoder payload (asset cache produces a typed `Material` struct per material index).

---

## 1. Goal

Provide physically-based material evaluation supporting metallics, roughness, normal map, AO, and an emissive channel, so the fox renders with physical realism. Material parameters are sourced from the GLB asset bundle decoded by Phase-1 `DPAsset.GLBDecoder`; no shader-side constants are user-authored. After SPEC-002 ships, switching the fox's material index from `0` to `1` changes the rendered look without any code edit — verifiable via screenshot diff.

---

## 2. Deliverables

- `DPRenderer.Material` value type:
  - `albedo (ColorOrTexture, .sRGB)`, `metallic (ScalarOrTexture, .linear)`, `roughness (ScalarOrTexture, .linear)`, `normalMap (NormalOrNil, .linear)`, `aoMap (ScalarOrTexture, .linear)`, `emissive (ColorOrTexture, .sRGB, intensity)`.
  - `SamplerDesc { minFilter, magFilter, wrapS, wrapT, anisoMax }`.
  - Factory: `Material.fromGlb(materialIndex:)` — reads `DPAsset.DecodedModel.materials[i]`.
- `DPRenderer.MaterialPass` (concrete `RenderPass`):
  - Encodes `materialPalette` uniforms; index by `DrawCall.materialIndex`.
  - GPU shader: PBR Cook-Torrance direct lighting **only** in this spec; IBL deferred to `spec-003-lighting.md`.
- Texture-hash cache (separate from `MemoryCache`): keyed on `(assetKey.hash, "albedo" | "normal" | …)`, declared in `DPAsset` namespace (the new spec extends Phase 1 module, doesn't open a new one).
- **Tests** (TDD per D-002):
  - Unit: `Material.fromGlb(i)` parses canonical `Tests/DPAssetTests/Fixtures/fox.glb` material `0` matching hand-coded reference values.
  - Unit: `MaterialPass.encode` produces a non-empty pipeline state (assertable via `MTLPipelineState` capture).
  - Visual: an in-test screenshot diff between the Phase-1 mono-tone draw (no MaterialPass) and the Phase-2 PBR result differs at ≥ 5 % pixel-level — assertable via mean-L2 distance.
  - Failure-path: GLB with `metallic` channel missing → `MaterialError.missingChannel(materialIndex:, channel:)` raised; never silent zero-default.
- **API docs**: `api/material-api.md` — texture serialization, channel coercion rules, gamma-space tags.

---

## 3. Out of Scope

- ❌ Subsurface scattering (SSS), anisotropic specular, clearcoat, sheen — Phase 8 Hardening if performance budget permits; otherwise dropped.
- ❌ Material editor UI — post-Phase 9.
- ❌ IBL / Environment lighting — `spec-003-lighting.md`.
- ❌ Shadow caster / receiver — `spec-004-shadow.md`.
- ❌ HDR / Tone Mapping — `spec-005-hdr-post.md`.
- ❌ Texture compression (KTX2 / BasisU) — Phase 8.

---

## 4. Risk

- **Texture-space mismatch**: GLB may declare UV-channel `0` empty or mirrored — Mitigation: hard assert in `Material` factory that `uvs.count > 0` for any channel except `emissive`; fail-fast boots Mod-load refuses.
- **GPU memory blow-up**: 4 K albedo at 2 K metallic roughness at 5 K normal on Apple Silicon shared UMA → Mitigation: per-material texture-budget cap ≤ 16 MB; if exceeded, downscale to nearest 2^N preset and log warning.
- **PBR shader divergence from energy-conservation standard** — Mitigation: hemisphere-light integral pre-computed at IBL startup; Cook-Torrance validated against Khronos PBR test mat (manual regression).
- **Color-space confusion** between `sRGB` albedo and `linear` normals — Mitigation: SamplerDesc carries gamma-tag; test fixture asserts each channel's tag matches reference.
- **Hot reload mid-frame** when a material is replaced — Mitigation: re-upload lives inside `MaterialPass` `nextFrame` queue only; current frame keeps old pipeline.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- Material re-bind cost ≤ 0.3 ms per draw call when re-binding the same SamplerState (CPU-side overhead).
- PBR shader ALU instruction count ≤ 220 (validated via Metal's offline `metal-ide-compute-info`).
- Memory ceiling added by `MaterialPass` ≤ 6 MB on top of Phase-1 baseline.

### Enumerable use case

- Material of fox index `0`: albedo `(0.85, 0.55, 0.30)` SRGB, metallic `0.00`, roughness `0.65`. Static reference render must match within ΔE ≤ 2 in CIE-Lab.
- Material of fox index `1` (when present in fixture): reference render differs from index `0` at ≥ 5 % mean-L2 distance.
- AO-only material (albedo white, aoMap = pre-baked, others defaults): AO modulation visibly darkens cavity samples in test screenshot; mean-L2 ≥ 2 % vs unmodulated baseline.

### Assertable state

- `Material.fromGlb(i)` is **pure** — calling twice with the same `(assetKey, i)` returns `==` instances (Phase 1 `MemoryCache` reuse).
- Missing channel throws `MaterialError.missingChannel` — never returns zero-default (regression test).
- `MaterialPass.gpuLabel == "pbr.material"` — Profiler counters labeled accordingly.
- Texture cache hit on second render of the same material asserts: `cache.lookup == .hit`, not `.miss`.

### Previous-Phase regression

- All Phase 1 `acceptance.md` rows 1..31 still pass — re-run `swift test` and CI green.
- `LandscapeGLBDecoderTests.testFixturesFoxGLB` (Phase 1 spec-004 row) still passes — Phase-2 material parser must not alter Phase-1 decoder output for the fixture.
- Memory baseline ≤ 80 MB worst-case (Phase-1 + ≤ 15 MB Renderer ceiling from `spec-001`).
