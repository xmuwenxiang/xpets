# Material Spec (PBR)

> Phase 2 PBR conventions.

---

## Slots

Each material carries:

- Basecolor (sRGB)
- Normal (linear, tangent space)
- Metallic (linear)
- Roughness (linear)
- AO (linear)
- Emissive (sRGB)
- IBL environment slot (per material)

## Naming

- `mat_<pet>_<part>` (e.g., `mat_fox_fur`, `mat_fox_eye`)
- Variant slot: `mat_<pet>_<part>_<variant>` (e.g., `mat_fox_fur_winter`)

## Validation

- Every material assignment must declare IBL slot (mandatory for PBR consistency).
- Phase 1 ships a single default material with basecolor only.

## Status

**Stub**. Filled when Phase 2 lands.
