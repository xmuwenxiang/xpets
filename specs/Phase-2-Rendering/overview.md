# Phase 2 — Rendering

> **Status**: Stub — Phase 1 closure gating begins content authoring.
> **Goal**: Bring up the Metal renderer with PBR materials, lighting (Directional / IBL), Shadow, Camera, HDR Environment.
> **Primary Output**: The same fox from Phase 1, now self-renders with physical realism — projected, reflective, rotatable, HDR-aware.

> ⚠️ **PLACEHOLDER — content authoring begins when Phase 1 closes.** The Acceptance prose below violates `00-spec-conventions.md` §3.5 / D-013 (4 categories + objective measurability) on purpose: it will be rewritten in 4-category form when Phase 2 starts. Do NOT use the lines below as Acceptance for Phase 2 closure.

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

## World Integration Reservation

None required from Phase 2 (Phase 3 / Phase 4 own it per D-003).

---

## Risk (placeholder — to be expanded)

- Metal Performance Shader compatibility on Apple Silicon
- IBL specular resolution vs frame budget
- Shadow acne with PBR materials
- Camera coordinate convention vs Phase 5 Desktop Space — addressed via the render-route decision documented in Phase 5a overview (D-005 lays out the 5a/5b split; the individual render-route sub-decision is left open until Phase 5a content authoring begins)

---

## Acceptance (placeholder — to be expanded using 4 categories)

- Fox self-renders with PBR realism
- HDR pipeline active with Tone Mapping
- Shadow cast onto ground plane
- Camera control stable across 60 s

---

## Cross-References

- Phase 1: `spec-003-runtime.md` (Scene), `spec-001-bootstrap.md` (Build)
- Phase 3: `spec-001-physics-engine.md` (depends on this)
- Phase 4: `spec-001-animator.md` (depends on this for material slot)
- Phase 5a: render-route decision sub-Spec (`spec-NNN-world-rendering-route.md`; file name chosen at Phase 5a start; **NOT** ADR D-005 — D-005 mandates the Phase 5 internal split only)
- ADRs: D-005 (Phase 5 split), D-008 (Profiler Performance-budget line carries into Phase 2 Acceptance)
