Status: Approved
Phase: 1 — Foundation
Owner: TBD
-->

# SPEC-005 — Animation Baseline (Skeleton + Idle)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> Depends on `spec-004-asset.md` (GLB decoder). Does NOT depend on `spec-006-profiler.md` but Profiler measures its cost.

---

## 1. Goal

Provide a minimal Skeleton + Animation runtime that:
1. Parses the embedded skeleton in `pets-models/fox.glb` (per D-004, Skeleton + Animation share one .glb).
2. Advances a single Idle animation driven by the Update Loop; Phase 4 IK additions (D-012) will compose ON TOP of this baseline, not modify it.
3. Drives a GPU skinning pass that the Renderer renders in Phase 2 with a basic lit material — in Phase 1 the material is unlit placeholder only.

After SPEC-005 is done, opening `DesktopPet.app` shows the fox at 60 FPS advancing its Idle animation. **No PBR. No blend tree (D-013 acceptance applies at Phase 4). No IK (D-012 applies at Phase 4). Just one clip playing.**

---

## 2. Deliverables

- `DPAnimation.Skeleton`:
  - Holds: `bones: [Bone]`, `parents: [Int?]`, `restPose: [float4x4]`.
  - Stable bone IDs: `JMINT` (joint integer ID matching GLTF joint index).
  - Methods:
    - `pose(at time: Double, clip: Animation) -> [float4x4]` — interpolated pose matrices.
    - `valid(skinIndices:) -> Bool` — verifies vertex skin weights cover joints.
- `DPAnimation.AnimationClip`:
  - Channel list: `[Channel { boneIndex, property: .translate|.rotate|.scale, keyframes: [Keyframe] }]`.
  - Sampled via cubic interpolation (Catmull-Rom on rotation, linear on translation/scale).
- `DPAnimation.Animator`:
  - Owns skeleton + active clip.
  - `tick(dt:)` advances the clip time.
  - `pose() -> [float4x4]` returns the current pose.
- `DPAnimation.SkinningPipeline`:
  - GPU-skinned mesh service: pushes vertex buffer indices + per-vertex `jointIndices/weights` to GPU and a per-frame `JointMatrixBuffer` SSBO equivalent.
  - Use vertex shader skinning (simple 4-joint weighted blend) — Phase 2 may move to compute pre-skinning.
- **Render-side** Mesh registration:
  - `Renderer.registerMesh(...)` consumes `Asset.GLB.mesh`; for Phase 1 only the basic unlit shader is wired.
- **Debug overlay** (very minimal):
  - Toggle via environment variable `DPT_DEBUG=1`; shows FPS + memory.
  - Phase 1 ships the code path only — full Debug Panel is Phase 8.
- **Tests**:
  - Unit: parse `tests/Fixtures/fox.glb` → Skeleton has expected bone count.
  - Integration: run Animator forward 5 s, verify pose matrices differ from rest pose.
  - GPU skinning: render the mesh into an off-screen Metal texture and verify pixel diff at frame 1 vs frame 60 is non-zero (the Idle animation actually affects pixels).
- **API docs**: `api/animation-api.md`.

---

## 3. Out of Scope

- ❌ BlendTree — Phase 4.
- ❌ Random Idle — Phase 4.
- ❌ Animation Layer — Phase 4.
- ❌ Any IK — Phase 4.
- ❌ PBR / lit shading — Phase 2.
- ❌ Multiple clips — Phase 4.
- ❌ Animation compression — Phase 8.
- ❌ Animation events / callbacks — Phase 4.
- ❌ Runtime retargeting — Phase 9.

---

## 4. Risk

| Risk | Mitigation |
|---|---|
| `pets-models/fox.glb` joint index convention differs from GLTF spec | Fixture hashed; assertion in `tests/Fixtures/fox.glb` joint-index test. |
| GPU skinning causes per-frame allocation on the SSBO | Double-buffer preallocated at startup; only writes inside. |
| Quaternion interpolation drift over long runtimes | Use shortest-arc slerp normalization between keyframes. |
| Time source drift between UpdateLoop and Animation's local timer | Animator uses the same `dt` provided by UpdateLoop; no internal clock. |
| Skeleton pose matrix needs transposed layout for shader | Centralize the transpose in `SkinningPipeline` only; ABI stable across modules. |
| Idle animation clip is non-looping | Validate loop flag at fixture load; non-loop logs a warning and restarts the clip at frame 0. |

---

## 5. Acceptance

### Performance Metrics
- [ ] Skinning 1 frame on M-series baseline **≤ 0.3 ms** at 60 FPS sustained.
- [ ] Idle animation timer drift over 60 s **≤ 16 ms**.
- [ ] Mesh upload (cold) **≤ 5 ms**.
- [ ] No per-frame allocations in the skinning path (verified by AllocationTracker).

### Enumerable Use Cases
- [ ] Boot → frame 1 the fox is visible at correct rest pose.
- [ ] After 1 s of running, the fox's ears/limb bones have moved (pose differs from rest pose).
- [ ] After 60 s, the fox continues to advance smoothly with no visible checkpoint restarts.
- [ ] `DPT_DEBUG=1` overlay shows FPS=60 ± 1, Memory ≤ 50 MB.

### Assertable States
- [ ] Skeleton bone count and joint mapping match `assets/fox-model-spec.md`.
- [ ] `Anim.tick(dt:)` advances clip playhead within tolerances of `Σ dt`.
- [ ] `pose()` returns matrices of shape `[boneCount × float4x4]` with no NaN / Inf.
- [ ] GPU skinning output pixels change between frame 1 and frame 60 (synthetic comparison test).

### Previous-Phase Regression
- [ ] `spec-004-asset.md` fixture GLB still parses after this Spec lands.
- [ ] `spec-006-profiler.md` Profiler reports FPS = 60 ± 1 with this animation running.

---

## 6. Trace

- Implements `roadmap.md` D-004.
- Provides skeleton + Idle baseline consumed by Phase 2 (Renderer) and Phase 4 (BlendTree / IK — top of stack).
- Architecture doc: `architecture/render-pipeline.md` (skinning stage placeholder).
- API doc: `api/animation-api.md`.
- Asset docs: `assets/animation-format-spec.md`, `assets/fox-model-spec.md` initial content written here.
