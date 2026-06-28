# Shader Naming

> Conventions for `.metal` files.

---

## File Tree

```
desktop-pet-core/Sources/DPRenderer/Shaders/
  base_color.metal              # Phase 1
  shadow_pass.metal             # Phase 2
  pbr_lighting.metal            # Phase 2
  hdr_tonemap.metal             # Phase 2
  ...
```

## Vertex Stage Function Naming

- `vertex_<target>` (e.g., `vertex_skinnedMesh`)
- Fragment: `fragment_<target>` (e.g., `fragment_unlitBaseColor`)

## Status

**Stub**. Phase 1 ships `base_color.metal` only; Phase 2 expands.
