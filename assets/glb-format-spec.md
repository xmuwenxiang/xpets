# glTF Format Spec (D-004)

> Per **D-004**, Skeleton + Animation embed inside one .glb. This file pins the asset format for the AI Native 3D Desktop Pet.

---

## Required Channels

Per `spec-004-asset.md` (D-004), every animal asset file MUST include:

| Channel | Required | Notes |
|---|---|---|
| Mesh primitives | ✅ | at least one |
| Skeleton | ✅ | embedded joint hierarchy |
| Joints | ✅ | glTF `skin.joints` array |
| Skeleton parent indices | ✅ | encoded in node hierarchy |
| Idle animation | at least 1 | glTF `animation` array |
| Texture basecolor | at least 1 | optional until Phase 2 |
| Material slot | ✅ | one default material (Phase 1) |

## Forbidden Patterns

- ❌ External `.bin` skeleton files
- ❌ External `.anim` / `.fbx` animation files
- ❌ Multi-file asset decomposition
- ❌ In-house custom extensions (KEEP phase-1 surface to glTF 2.0 only)

## Validation

- Loader test: `Tests/DPAssetTests/Fixtures/fox.glb` is hashed; loader must accept.
- Schema validation: malformed GLB returns `AssetLoadError.schemaMismatch(field:)`.

## Status

**Active**. Phase 1 consequence of D-004; Phase 2 expands TCP for PBR textures without changing schema.
