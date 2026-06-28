# D-012 — Phase 4 IK Scope Locked to Four Variants

## Status
Accepted · 2026-06-28

## Context
IK is a broad space (FABRIK, CCD, Jacobian-transpose, Look-At variants, Constraint IK). Without fixing the scope upfront, Phase 4 risks scope creep — every new IK variant uses a different solver, different convergence guarantees, different cost profile. Apple ships a fixed IK surface per skeleton asset; replicating that discipline prevents intra-Phase spec drift.

## Considered Alternatives
- **A.** Open-ended IK: cover every algorithm the team might want.
- **B.** Lock to four variants: Two-Bone (ears), CCD (tail chain), Foot IK (legs), Look-At IK (head + eyes). **← Chosen.**

## Decision
Phase 4 ships exactly four IK variants, no others in Phase 4:

| IK Type | Solver | Applied To |
|---|---|---|
| Two-Bone IK | analytical | Ears |
| CCD IK | cyclic-coordinate descent | Tail chain |
| Foot IK | Two-Bone + ray-cast ground probe | Fore-legs + hind-legs |
| Look-At IK | quaternion-lerp + clamp | Head + Eyes |

Phase 6+ may add additional IK variants (e.g., Constraint IK for props) only via new ADRs that amend D-012.

## Rationale
- Four variants cover all observed quadruped animation needs (eat, walk, plant on slope, head-track cursor).
- Two-Bone is provably optimal (< 3 ms at 60 FPS) for ears.
- CCD is the only candidate with bounded runtime for tail chains of length > 3.
- Foot IK is mandatory for Phase 5 dock-mount.
- Look-At IK is mandatory for cursor and Phase 5 world entity tracking.

## Consequences
- (+) Phase 4 has a stable performance budget.
- (+) Phase 5 dock-mount is feasible in one Sprint.
- (–) Future IK additions (e.g., FABRIK) require new ADRs.

## Trace
- `specs/Phase-4-Animation/overview.md` IK Scope section
- `specs/Phase-4-Animation/spec-NNN-ik-system.md` (drafted at Phase 4 start)
- `specs/Phase-5-DesktopWorld/overview.md` (Foot IK dependency)
