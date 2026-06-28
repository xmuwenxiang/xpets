<!--
Status: Draft
Phase: 2 — Rendering
Owner: TBD
Depends: Phase 2 spec-001-metal-renderer.md, spec-003-lighting.md
ADRs:   D-008, D-013
-->

# SPEC-005 — HDR + Tone Mapping + FXAA (+ Bloom reserved)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> HDR pipeline wraps the Phase-2 framebuffer (PBR → Lighting → Shadow) with a tone-mapped display presentation. **FXAA** is a Phase 2 ship; **Bloom** is interface-reserved-only (no implementation in Phase 2 — Phase 8 if budget allows).

---

## 1. Goal

Provide an HDR-capable framebuffer that accepts linear-light contributions from PBR + IBL + Shadow, applies tone mapping in display space, and outputs a final 8-bit framebuffer to the screen. The fox must exhibit **burst highlights** (specular reflections > 1.0 linear) without clipping to white unless tone-mapped; tone mapping is required to map the HDR signal into 0..1 sRGB.

After SPEC-005 ships, blocking all lighting (DirLight = 0, IBL = null) renders a perfectly black screen; full-intensity DirLight + IBL renders the fox with non-clipped highlights in the brightest regions.

---

## 2. Deliverables

- `DPRenderer.HDRConfig`:
  - `toneMapper: .none | .reinhard | .filmic | .acesFilmic` (default `.acesFilmic`).
  - `exposure: Float` — default 1.0; range [0.25, 4.0].
  - `fxaaQuality: .off | .low | .medium | .high` (default `.medium`).
  - `bloom: { enabled: false }` — placeholder struct; `enabled = true` is a faithful no-op (mirrors D-007 stub precedent).
- `DPRenderer.HDRPostPass` (final `RenderPass`):
  - Allocates an `MTLTexture` of `MTLPixelFormat.rgba16Float` as the post-pipeline framebuffer.
  - Reads `PBR + Lighting + Shadow` output, tone-maps, applies FXAA, writes to the canvas.
  - GPU labels: `hdr.tonemap`, `hdr.fxaa`.
- `DPRenderer.BloomPass` (reserved interface only — no encoding in Phase 2):
  - Public type stub with `register()` + `unregister()` methods that log "Phase 8 implementation pending" if invoked.
  - Test asserts `register()` returns without renderer-thread mutation.
- **Tests** (TDD per D-002):
  - Unit: scene with full-intensity DirLight + IBL → rendered pixel max-Y in canvas ≤ 1.0 (no additive clipping past tone-mapping).
  - Unit: completely black scene → pixel max-Y == 0 (no leakage from environment).
  - Unit: `toneMapper = .reinhard`: brightest sample ≤ 1.0; `toneMapper = .none`: a literal 1.5 input becomes clipped to 1.0 — assertable.
  - Unit: `BloomPass.register()` is no-op when `enabled = false`; `enabled = true` only logs to console; no observable effect.
  - Visual: full-intensity fox vs zero-intensity fox — reference screenshot ΔE > 50.
- **API docs**: `api/hdr-api.md` — framebuffer ownership, exposure-mapping math, FXAA quality ↔ pixel-shader cost table.

---

## 3. Out of Scope

- ❌ **Bloom implementation** (placeholder only) — Phase 8; Phase 2 reserves the interface type.
- ❌ **Chromatic aberration / Vignette** — Phase 8.
- ❌ **SMAA / TAA** — Phase 8; Phase 2 ships FXAA only.
- ❌ **Multi-viewport HDR merge** — Phase 8.
- ❌ **HDR capture / replay** (Encoded Frame Capture) — Phase 8.
- ❌ **Output `Rec. 2020` color space** — Phase 9.

---

## 4. Risk

- **Tone-mapper bias determines correctness** — Mitigation: default `.acesFilmic` is the Khronos reference; constants stored in a single source-of-truth struct; CI cross-validates against hand-coded LUTs.
- **HDR framebuffer memory cost** — 1920×1080 × 8 bytes RGBA16F = 16 MB; Mitigation: scale framebuffer by `backingScaleFactor`; on a Retina display, full framebuffer ≤ 32 MB.
- **FXAA cost on Apple Silicon** — Mitigation: FXAA is single-pass post; `.medium` quality ≤ 0.4 ms / frame on M2.
- **Stub `BloomPass` polluting the registry** — Mitigation: stub `register()` increments a counter and **does not append to the Pass list**; test asserts registry length unchanged.
- **Exposure mapping drift** between `LightingPass` and `HDRPostPass` — Mitigation: `exposure` is a single shared property owned by `HDRConfig` passed through both; no internal copies.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- `HDRPostPass` GPU-time P99 ≤ 1.2 ms (full pipeline incl. FXAA) on macos-14 / M2.
- HDR framebuffer steady-state memory ≤ 32 MB worst-case (incl. Retina 2×).
- `BloomPass.register()` adds **zero** GPU time (proves stub is dormant).
- Profiler `.everyFrame` overhead remains ≤ 0.5 ms (Phase-1 row 24) through Phase 2 — **no post-pass assertions may regress this**.

### Enumerable use case

- `toneMapper = .acesFilmic` + DirLight intensity = 1.0: fox specular highlights visible; max-channel ≤ 1.0; reference screenshot ΔE ≤ 4.
- `toneMapper = .none` (clipped): brightest pixels clamp to 1.0; visible bright-edge band; reference comparison.
- `exposure = 0.5`: scene dims by ≈ 1 f-stop; screenshot diff ≥ ΔE = 3 vs exposure = 1.0.
- `fxaaQuality = .off` vs `.high`: high-quality render must show ≥ 1 % reduction in edge-aliasing metric (assertable sample).
- Fox at full-intensity vs zero-intensity: pixel mean luminance ratio ≥ 10×.

### Assertable state

- `HDRConfig.toneMapper` switch is `Codable`; can be persisted via `DPFoundation.Config` round-trip.
- `BloomPass.register()` returns without modifying `Renderer` pass-order list — assertable via `passes.count` invariant.
- HDR framebuffer is `Sendable`; ownership transitions across Renderer thread without race.
- `exposure = 0.25` vs `exposure = 4.0` produces a deterministic pixel ratio; same input exponentially affects output.

### Previous-Phase regression

- All Phase 1 + Phase-2 spec-001..004 Acceptance still pass.
- **Memory ceiling**: cumulative Phase 2 worst-case baseline must sum ≤ **< 128 MB** (Phase-1 65 + Renderer 15 + Material 6 + Lighting 6 + Shadow 24 + HDR 12). If implementation exceeds this, Phase 2 cannot close and a `findings.md` ADR must be raised to either accept the delta or defer a sub-Spec.
- Profiler budget row (Phase-1 row 24 ≤ 0.5 ms) re-asserted at end of Phase 2 acceptance.
