# Render Pipeline

> Metal frame graph and pass order for the AI Native 3D Desktop Pet. Targets **Apple Silicon** + **macOS 14+**.

---

## High-Level Frame Pipeline

```
                CADisplayLink callback
                          │
                ┌─────────▼─────────┐
                │   Application    │  (DPRuntime.UpdateLoop)
                │   Update phase    │
                └─────────┬─────────┘
                          │
              moduleDidTick(dt) ─┬─ Renderer.submitFrame()
                          │      │   (issue MTLCommandBuffer)
                          │      │
                ┌─────────▼──────▼─────────┐
                │   Metal Render Queue      │
                │   ┌──────────────────┐   │
                │   │ 1. Shadow Pass    │   │  (Phase 2)
                │   │ 2. Base Color    │   │
                │   │ 3. Lighting      │   │
                │   │ 4. PBR compose   │   │
                │   │ 5. Post-fx       │   │
                │   │ 6. Final blit    │   │
                │   └──────────────────┘   │
                └─────────┬─────────────────┘
                          │
                drawable presented to Window's MTKView
```

---

## Phase 1 — Render Surface Only

Phase 1 has **no PBR passes**. The render pass is a single "Base Color" pass:

- Vertex shader: GPU-skinned mesh (per `spec-005-animation.md`).
- Fragment shader: unlit sampler — base texture only.
- No shadow, no lighting, no post-fx.
- Profiler samples `MTLCommandBuffer.gpuStartTime` / `gpuEndTime` (per D-008).

---

## Phase 2 — PBR Pipeline Plan

Adds (per `spec-NNN` files Phase 2):

1. **Shadow Pass**: depth-only render to shadow map.
2. **G-Buffer**: albedo, normal, roughness, metallic, AO.
3. **Lighting Pass**: Directional + IBL.
4. **Composition**: ambient + direct, output linear HDR.
5. **Tone Mapping**: ACES filmic → sRGB.
6. **Post-FX**: Bloom (Phase 8 may add), FXAA.

---

## Performance Targets

| Metric | Phase 1 | Phase 2 | Phase 8 (Hardening) |
|---|---|---|---|
| Frame time P99 | ≤ 18 ms | ≤ 18 ms | ≤ 12 ms |
| GPU time | (sampled, no budget) | ≤ 8 ms | ≤ 6 ms |
| Draw calls | ≤ 10 (fox only) | ≤ 50 | ≤ 50 |

---

## Status

**Stub**. Pass-graph corresponds to Phase 2 specifications and Phase 1 deliverable (Base Color only).
