# D-004 — Skeleton + Animation Embedded in .glb

## Status
Accepted · 2026-06-28

## Context
The legacy v1 plan (`specs/_legacy/specs-v1-44-spec-DEPRECATED.md` SPEC-012 / SPEC-013 / SPEC-031) implied separate skeleton and animation files alongside the mesh. In practice the artist's source-of-truth is one .glb binary; separate files cause Skeleton / Animation synchronization drift, version mismatch, and Asset Pipeline rework when rig changes.

## Considered Alternatives
- **A.** Separate Skeleton (.json or .sfx) + Animation (.anim or .fbx) files alongside .glb. **← Rejected.**
- **B.** Embed Skeleton + Animation inside one .glb binary (glTF 2.0 compliant). **← Chosen.**
- **C.** Custom binary container; in-house .petformat.

## Decision
From Phase 1 onward, the canonical asset `pets-models/fox.glb` carries the mesh, Skeleton, and Idle Animation inside one glTF 2.0 binary per glTF's "Skinned Mesh + Animation" specification.

## Rationale
- One file = one version = no Skeleton/Animation drift.
- glTF 2.0 spec is well-supported; loaders are off-the-shelf.
- Animator + Renderer can read a single buffer (single load, single cache key) — see D-004's downstream effect on Asset memory cap.

## Consequences
- (+) Single source of truth for the pet asset.
- (+) glTF 2.0 loader ecosystem applies.
- (–) Limited to glTF channels; advanced runtime retargeting still requires extra tooling (deferred to Phase 9).

## Trace
- `specs/Phase-1-Foundation/spec-004-asset.md` (GLBDecoder)
- `specs/Phase-1-Foundation/spec-005-animation.md` (Skeleton + Idle)
- `assets/glb-format-spec.md`
- `assets/animation-format-spec.md`
