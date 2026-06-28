# Phase 2 — Rendering

> **Status**: Stub → **Drafts authored (2026-06-28)**. Five Work Specs now exist at Apple Style + 4-category Acceptance; none has entered `In Review`. Implementation does not begin until owner review + `Status: Approved` per `00-spec-conventions.md` §7.
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
