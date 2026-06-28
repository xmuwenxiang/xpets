# DPRenderer API

> Module: `DPRenderer` · Owner Phase: 1 (stub) + Phase 2 (full)
> Related: `architecture/render-pipeline.md`

---

## Public Surface (Phase 1 — stub)

```
public final class Renderer {
    public init(device: MTLDevice, view: MTKView) throws
    public func registerRenderable(_ r: any Renderable)
    public func submitFrame(scene: Scene)
    public func shutdown()
}
```

## Phase 2 extension

- PBR shader pipeline
- Shadow pass registration
- HDR / Tone Mapping
- IBL environment handling

## Status

**Stub**. Phase 1 ships Renderer + MTKView handoff + GPU time sampling. Phase 2 fills shader pipeline.
