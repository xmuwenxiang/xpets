# Assets

> Artifact contracts: file formats, naming, validation, compression. Anything a non-engineer (artist / animator / editor) needs to know to ship a resource **without breaking the engine**.

---

## Contents

| File | Artifact | Owner Phase |
|---|---|---|
| `fox-model-spec.md` | The current canonical pet: `pets-models/fox.glb` — schema, transforms, scale units | Phase 1 + Phase 2 |
| `glb-format-spec.md` | Embedded skeleton + animation (D-004): bone conventions, mesh slot, skinning attributes | Phase 1 |
| `animation-format-spec.md` | glTF animation channel rules, sampling rate, rest pose | Phase 1 + Phase 4 |
| `texture-spec.md` | KTX2 / BC compression, color space, sRGB vs linear split | Phase 2 |
| `material-spec.md` | PBR material slot conventions, naming, environment IBL slot | Phase 2 |
| `shader-naming.md` | Vertex / fragment / compute shader conventions | Phase 2 |

---

## Cross-Phase Lock-in

Per **D-004**, all Skeleton + Animation must embed inside the .glb file from Phase 1 onward. This avoids the legacy Asset Pipeline split (separate Skeleton file + separate Animation clip file) that historically caused Phase 3/4 rework.

Any deviation requires an ADR (`decisions/`).

---

## Status

This directory is **scaffolded**. File contents fill as the corresponding Phase specs reach `Status: Implementing`.
