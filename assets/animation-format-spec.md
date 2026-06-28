# Animation Format Spec

> Per **D-004**, Animation is embedded in the .glb file. This file documents the channel conventions.

---

## Channel Conventions

| Property | Convention |
|---|---|
| Time ticks | glTF default (seconds, float) |
| Translation | cubic-spline interpolation; **linear acceptable for grip motion** |
| Rotation | quaternion cubic (Catmull-Rom); shortest-arc slerp |
| Scale | linear interpolation |
| Sampled rate | 30 fps minimum (asset-conditional) |

## Loop Flag

Every clip MUST declare `isLooping` in the Animator (not always in glTF). Phase 1 checks loop flag at fixture load; non-loop clips log a warning and restart at frame 0.

## Reserved Channel Names (Phase 4 IK / Animator binding)

- `lookAt` — Look-At IK target (Phase 4)
- `foot_L` / `foot_R` — Foot IK target (Phase 4)
- `tailTip` — CCD IK chain tail (Phase 4)

These are **reserved strings** in Phase 1 to prevent Phase 4 retargeting costs.

## Status

**Stub**. Phase 4 IK range expands the spec.
