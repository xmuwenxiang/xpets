<!--
Status: Draft
Phase: 2 — Rendering
Owner: TBD
Depends: Phase 2 spec-001-metal-renderer.md, spec-002-material-pbr.md, spec-003-lighting.md
ADRs:   D-003 (Phase 5 world integration hookup), D-008, D-013
-->

# SPEC-004 — Shadow

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> Shadow is split into **Soft Shadow** (cascaded Directional shadow map), **Contact Shadow** (ray-marched AO under feet, deferred to Phase 8 visually but reserved as interface here), and **Dynamic Shadow** (per-mesh caster tracking — single Directional light only in Phase 2).

---

## 1. Goal

Produce a shadow that grounds the fox on the implicit ground plane so it stops looking "floating". Phase 2 ships Soft + Dynamic; Contact Shadow is **reserved interface only** in Phase 2 (no implementation, no test fixture) because per D-003 the *full* Contact Shadow integration belongs to Phase 5a's desktop-world rendering route decision.

After SPEC-004 ships, the fox casts a soft shadow on a synthetic ground plane (large invisible quad) inside the renderer; the shadow sharpens as the Directional light steepens.

---

## 2. Deliverables

- `DPRenderer.ShadowConfig`:
  - `cascadeCount: 1..4` (default 2 for Phase 2).
  - `resolution: 512 | 1024 | 2048` per cascade.
  - `biasMode: .constant | .adaptive | .slopeScaled`.
  - `softness: 0.0 .. 1.0` (PCF kernel radius).
- `DPRenderer.ShadowPass` (concrete `RenderPass`):
  - Renders depth from the directional light's view-projection matrix into a `MTLTexture` array (one slice per cascade).
  - Soft filter: PCF 5×5 with configurable radius.
- Sampling: PBR fragment shader (from `spec-002` / `spec-003` reading) reads the appropriate cascade slice based on world-space distance from camera. Trilinear filtering across cascades.
- **Reserved (no implementation)**:
  - `DPRenderer.ContactShadowToggle { enable, intensity }` — included as a no-op pass that **does nothing** in Phase 2. Tagged `// Phase 5a implements the desktop-aware variant`. Test asserts that calling `enable = true` does not change render output but the toggle code path runs without error.
- **Tests** (TDD per D-002):
  - Unit: shadow map dimensions match `cascadeCount × resolution` invariant — test asserts texture array length.
  - Unit: PCF kernel radius change → visible softening in the depth buffer test (assertable via mean L2 of the depth texture).
  - Unit: `ContactShadowToggle.enable = true` does NOT throw and does NOT mutate per-frame output (deterministic test).
  - Visual: fox at origin, DirLight at 45° elevation: shadow visible on ground plane; visual screenshot ΔE vs reference ≤ 4.
- **API docs**: `api/shadow-api.md` — cascade allocation policy, depth-bias tuning knobs.

---

## 3. Out of Scope

- ❌ Screen-space contact shadows (SSCS) / ray-marched fine detail — Phase 8; Phase 5a reserves the toggle but Phase 2 leaves it dormant.
- ❌ Point / Spot light shadows — Phase 8 / post-Phase 9.
- ❌ Cascaded shadow map with more than 4 cascades — Phase 8.
- ❌ Shadow self-intersection fix-up — Phase 8.
- ❌ VSM (variance shadow maps) and other alternatives — explicitly rejected for Phase 2.

---

## 4. Risk

- **Shadow acne on metallic low-roughness surfaces** — Mitigation: `biasMode = .slopeScaled` is the Phase 2 default; PBR shader reads the bias from `ShadowConfig`.
- **Cascade resolution under-budget** when the fox is near the screen edge — Mitigation: split ratio `[0.20, 0.30, 0.50]` (2 cascades × 2048) — fixed but tunable at runtime via `ShadowConfig`.
- **Per-frame depth-target allocation cost** — Mitigation: depth textures allocated once at boot (sized to the largest cascade); reused every frame, asserted in test as no `MTLTexture` allocation in steady-state.
- **Contact-shadow toggle code path injection** without proper Phase-2 implementation — Mitigation: interface is locked at `DPRenderer.ContactShadowToggle { enable, intensity }`; `enable` setter is **a faithful no-op stub** (no-op stubs are explicitly *required* by D-007 protocol-stub precedent); the test asserts no-render-side-effect.
- **Renderer thread ownership** of the depth-texture — Mitigation: depth textures are owned by the Shadow pass; tests assert weak-pointer release on `unregisterPass`.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- `ShadowPass.encode` GPU-time P99 ≤ 2.5 ms at 2 cascades × 2048 (worst Phase-2 case) on macos-14 / M2 / 60 FPS.
- Steady-state memory delta from shadow textures ≤ 24 MB (2 × 2048² × 4 bytes RGBA_depth; using `MTLPixelFormat.depth32Float` 8-byte = 16 MB, plus PBR bias buffer).
- `ContactShadowToggle enable=true` adds **zero** extra GPU time per frame (proves the stub is dormant).

### Enumerable use case

- 1 cascade × 512: shadow visible but chunky; test pixel-shadow coverage ≥ 30 %.
- 2 cascade × 2048: shadow sharp; test ΔE vs reference ≤ 3.
- 4 cascade × 2048: full cascade budget; render time stays under Phase 2 budget; test asserts no MTLTexture reallocation in 60-frame run.
- `biasMode = .adaptive`: tree-fox edges (high-frequency normal area) no longer show shadow acne at 5+ trials of randomized light direction.

### Assertable state

- Shadow map counts: `MTLTexture.arrayLength == cascadeCount` invariant.
- `ShadowConfig.cascadeCount = 0` throws `ShadowError.invalidCascadeCount` at registration time, never into the encoder.
- `ContactShadowToggle` setters are `Sendable`-safe — crossing Renderer thread does not crash.
- After `unregisterPass(id: shadow)` during runtime: depth textures are released (`weak var weakDepth == nil` after drain).

### Previous-Phase regression

- All Phase 1, plus Phase-2 spec-001/002/003 Acceptance items still pass.
- Memory delta ≤ 30 MB added by `spec-004` (sum check: baseline 65 + Renderer 15 + Material 6 + Lighting 6 + Shadow 24 ≤ **116 MB worst-case** — in line with Phase 8 hard target < 100 MB rendered-runtime budget; Phase 2 ends roughly within striking distance).
