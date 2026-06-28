# Texture Spec

> Phase 2 onwards. Phase 1 uses PNG / texture-internal fallback only.

---

## Compression

| Format | Use case |
|---|---|
| KTX2 (BC7) | Basecolor normal-quality on disk |
| KTX2 (BC5) | Normal maps |
| KTX2 (BC1) | Roughness / Metallic / AO (single channel) |

## Color Space

| Channel | Color space |
|---|---|
| Basecolor | sRGB |
| Normal | Linear |
| R / M / AO | Linear |
| Emissive | sRGB |

## Mipmap

- Always mip chain. Phase 8 (Hardening) may drop lower mips for super-small distant Pet.

## Status

**Stub**. Filled when Phase 2 lands.
