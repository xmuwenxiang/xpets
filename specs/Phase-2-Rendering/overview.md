# Phase 2 — Rendering

> **Status**: **Approved (2026-06-29)**. Five Work Specs at Apple Style + 4-category Acceptance, owner-reviewed. Implementation may begin per `00-spec-conventions.md` §7; execution plan in [`execution-plan.md`](execution-plan.md).
> **Goal**: Bring up the Metal renderer with PBR materials, lighting (Directional / IBL), Shadow, Camera, HDR Environment.
> **Primary Output**: The same fox from Phase 1, now self-renders with physical realism — projected, reflective, rotatable, HDR-aware.

> The five Draft Work Specs are below. Acceptance prose is **finalized** in 4-category form per D-013; numeric thresholds are owner-tunable at the Phase-2 kickoff.

---

## Goal (Phase 2 final)

The fox is rendered using a fully PBR pipeline. Materials react to a directional light producer and an HDR environment map. Shadows cast onto a fake ground plane. Camera is orthographic option + perspective.

---

## Pre-known Deliverables (to be expanded when Phase 2 starts)

- `spec-001-metal-renderer.md` — Renderer + Camera + Pass registration
- `spec-002-material-pbr.md` — PBR, Metallic, Roughness, Normal, AO, IBL
- `spec-003-lighting.md` — Directional Light, IBL, Environment Map
- `spec-004-shadow.md` — Soft Shadow, Contact Shadow, Dynamic Shadow
- `spec-005-hdr-post.md` — HDR, Tone Mapping, FXAA, Bloom (later Phase 8)

---

## Out of Scope (Phase 2)

- ❌ Physics — Phase 3
- ❌ Animation richness — Phase 4
- ❌ Desktop World — Phase 5
- ❌ AI / Behavior — Phase 6 / 7

---

## Future-Spec Reservations (orphaned no-op stubs)

`spec-004-shadow.md` declared a `DPRenderer.ContactShadowToggle { enable, intensity }` no-op stub with a comment promising "Phase 5a implements the desktop-aware variant". As of Phase-2 closure (per `_audit-cross-ref.md` Dimension 5), **no Phase-5 Work Spec consumes this stub**, and there is no concrete plan to implement ContactShadow in any sibling Phase. Resolution:

- **Post-Phase-9 roadmap item**: ContactShadow is *post-Phase-9*. Phase-2 ships the stub as a placeholder for forward-compatibility, and the stub is faithful zero-cost (no GPU / CPU overhead).
- The Phase-2 stub remains in the public API; ADR is **not** required to retire it.
- Concrete implementation lands under `spec-009-contact-shadow.md` if/when Phase-10 / post-Phase-9 picks it up.

Similarly, `spec-005-hdr-post.md` declared a `DPRenderer.BloomPass` no-op stub. As of Phase-2 closure:

- **Phase-8 defer**: BloomPass is *not* in Phase-8 Hardening's planned budget reductions (those target敾 8 MB from HDR format change alone). Post-Phase-9 roadmap item.
- The Phase-2 stub remains in the public API; Phase-8 spec files make no reference.

These are documented as **Future-Spec reservations** — not blocking Phase-2 / Phase-8 closure.

---

## World Integration Reservation

None required from Phase 2 (Phase 3 / Phase 4 own it per D-003).

---

## Risk

- **MPS compatibility on Apple Silicon** — Phase 2 ships hand-written Metal shaders; MPS is not on the critical path. If a later spec pulls in MPS, gate on `macos-14` runner only.
- **IBL specular resolution vs frame budget** — pre-filtered mip chain generated once at boot (async on a background `DispatchQueue`, synthetic-gradient fallback for the first frame); steady-state probe is cached, not rebuilt per frame (spec-003 §4).
- **Shadow acne on PBR low-roughness surfaces** — `biasMode = .slopeScaled` is the Phase-2 default; PBR shader reads bias from `ShadowConfig` (spec-004 §4).
- **Camera coordinate convention vs Phase 5 Desktop Space** — world-relative light direction stored as `SIMD3<Float>`; renderer recomputes view-projection on resize. The render-route sub-decision (offscreen-compositor vs direct-on-window) is owned by Phase 5a per D-005; Phase 2 only governs the renderer surface, not the route.

---

## Acceptance

> Distilled from the 5 Work Specs; full per-item table in [`acceptance.md`](acceptance.md). 4-category form per D-013.

### Performance metric

- `Renderer.tick(_:)` CPU ≤ 4 ms @ 60 FPS with 6 Passes registered (spec-001).
- no-op Pass GPU P99 ≤ 0.5 ms over 600-frame window (spec-001 backbone overhead); heavy passes carry per-spec P99 budgets (Lighting ≤ 1.5 ms, Shadow ≤ 2.5 ms, HDR ≤ 1.2 ms).
- Profiler `.everyFrame` overhead ≤ 0.5 ms / frame through Phase 2 (Phase-1 row 24 regression).
- Cumulative Phase-2 memory ≤ 128 MB worst-case (65 baseline + Renderer 15 + Material 6 + Lighting 6 + Shadow 24 + HDR 12).

### Enumerable use case

- Register 4 passes → order `[root, A, B, C, D]`; unregister `B` → `[root, A, C, D]` (spec-001).
- Material index `0` vs `1` → render differs at ≥ 5 % mean-L2 (spec-002).
- DirLight rotated 90° around Y → specular highlight follows (spec-003).
- 1 / 2 / 4 cascade × 512 / 2048 / 2048 → shadow coverage / sharpness / no `MTLTexture` reallocation in 60-frame run (spec-004).
- `toneMapper = .acesFilmic` vs `.none` → clipped bright-edge band; `exposure = 0.5` vs `1.0` ΔE ≥ 3 (spec-005).

### Assertable state

- `Renderer.currentFrameIndex == 0` at init, +1 per `tick`; `MTLDevice` in-process count == 1 (spec-001).
- `Material.fromGlb(i)` pure (== on repeat); `missingChannel` throws; texture cache `.hit` on second render (spec-002).
- `LightingState` `Sendable`; IBL probe cached `==`; `noLightsDuringIBLFallback` fires in strict mode only (spec-003).
- `MTLTexture.arrayLength == cascadeCount`; `invalidCascadeCount` throws at registration; `ContactShadowToggle.enable = true` zero side-effect (spec-004).
- `HDRConfig.toneMapper` `Codable` round-trip; `BloomPass.register()` does not mutate pass-order list; black scene → canvas max-Y == 0 (spec-005).

### Previous-Phase regression

- All Phase-1 `acceptance.md` rows 1..31 still pass — re-run `swift test` + CI green.
- Memory baseline ≤ 65 MB must not exceed 80 MB after spec-001 (≤ 15 MB Renderer ceiling); cumulative ≤ 128 MB at Phase-2 close.

---

## Cross-References

- Phase 1: `spec-003-runtime.md` (Scene), `spec-001-bootstrap.md` (Build)
- Phase 3: `spec-001-physics-engine.md` (depends on this)
- Phase 4: `spec-001-animator.md` (depends on this for material slot)
- Phase 5a: render-route decision sub-Spec (`spec-NNN-world-rendering-route.md`; file name chosen at Phase 5a start; **NOT** ADR D-005 — D-005 mandates the Phase 5 internal split only)
- ADRs: D-005 (Phase 5 split), D-008 (Profiler Performance-budget line carries into Phase 2 Acceptance)
