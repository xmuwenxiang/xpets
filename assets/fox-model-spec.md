# Fox Model Spec

> Canonical pet asset: `pets-models/fox.glb`
> Owner: Phase 1 (D-004 embedding) + Phase 2 (PBR upgrades)

---

## Dimensions

| Field | Value |
|---|---|
| Source file | `pets-models/fox.glb` |
| Format | glTF 2.0 embedded binary |
| Bone count | TBD — pinned by fixture test (Phase 1) |
| Skeleton | flat hierarchy, root at hip |
| Idle animation | single clip (`idle_loop_01`), duration ≈ 4 s, looping |
| Materials | single material slot (Phase 1) → multi-slot PBR in Phase 2 |
| Texture slots | 1 basecolor (Phase 1) → + normal + ORM in Phase 2 |

## Coordinate Convention

- Right-handed, Y-up.
- Unit: 1 unit = 1 cm (Pet world scale).
- Mesh origin: between front paws on floor plane.

## Validation

- Frozen fixture hash is committed under `Tests/DPAssetTests/Fixtures/fox.glb`.
- Any drift to `pets-models/fox.glb` triggers a Phase 1 integration test failure.

## Status

**Stub**. Final values pinned at Phase 1 close-out when `spec-005-animation.md` lands.
