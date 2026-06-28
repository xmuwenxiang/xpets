# DPAnimation API

> Module: `DPAnimation` · Owner Phase: 1 (baseline); Phase 4 (richness)
> Related: `specs/Phase-1-Foundation/spec-005-animation.md`, D-012 (IK scope), D-013

---

## Public Surface (Phase 1)

```
public final class Skeleton {
    public let bones: [Bone]
    public let parents: [Int?]
    public let restPose: [float4x4]
    public func pose(at time: Double, clip: AnimationClip) -> [float4x4]
    public func valid(skinIndices: [UInt16]) -> Bool
}

public final class AnimationClip {
    public let channels: [Channel]
    public let durationSeconds: Double
    public let isLooping: Bool
}

public final class Animator {
    public init(skeleton: Skeleton, clip: AnimationClip)
    public func tick(dt: TimeInterval)
    public func pose() -> [float4x4]
}

public final class SkinningPipeline {
    public init(skeleton: Skeleton, mesh: Mesh)
    public func encodeJointMatrices(buffer: inout [float4x4])
    public func apply(to encoder: MTLRenderCommandEncoder)
}
```

## Phase 4 additions (D-012, D-007 cross-deliver)

- `AnimationDriver` protocol (D-003 / D-007): `(Bone, WorldPoint) -> apply(offset)`.
  - Phase 4 ships the protocol only.
  - Phase 5 fills the body.
- 4 IK solvers: `TwoBoneIK`, `CCDIK`, `FootIK`, `LookAtIK`.
- `BlendTree`, `RandomIdlePicker`, `AnimationLayer`.

## Invariants

- `Animator.tick` advances clip playhead using UpdateLoop's `dt`. No internal clock.
- Quaternion interpolation uses shortest-arc slerp.
- `SkinningPipeline.apply` allocates nothing per frame.

## Error Modes

| Method | Throws |
|---|---|
| `Skeleton.pose` | none (clamps or no-ops on invalid time) |
| `Animator.tick` | none (silently skips) |
| `SkinningPipeline.apply` | `MetalBufferError` if buffer overfull |

## Test Hooks

- `AnimatorTester`: predetermined dt stream.
- `PoseSnapshot`: structurally compares `pose()` matrices.

## Status

**Stub**. Filled when `spec-005-animation.md` lands. Phase 4 surface extends.
