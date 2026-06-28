<!--
Status: Drafts authored (2026-06-28)
Phase: 4 — Animation
Owner: TBD
ADRs:  D-003 (World Integration Reservation — `AnimationDriver` signature), D-007 (Phase-5 cross-delivers the implementation), D-008, D-012 (4 IK variants), D-013
-->

# Phase 4 — Animation

> **Status**: Stub → **Drafts authored (2026-06-28)**. Four Work Specs now exist at Apple Style + 4-category Acceptance; implementation gated on owner review + `Status: Approved`.
> **Goal**: Bring up BlendTree, 4 IK variants (Two-Bone / CCD / Foot / Look-At) per **D-012**, Random Idle, Animation Layer. Phase 4 enables Phase 5's Pet-World interaction (legs plant on the dock via Foot IK).
> **Primary Output**: A fox with rich motion — head pursues cursor, ears twitch, feet plant on slopes, idle randomly varies, layered expressions stack.

> Per **D-003 + D-007**, this Phase **MUST carry a World Integration Reservation in `AnimationDriver` signature only** — see [`spec-004-animation-driver.md`](spec-004-animation-driver.md). Phase 4 ships **no implementation**; Phase 5 fills the body per **D-007**.

---

## 1. Goal (Phase 4 final)

All four IK types are wired into the rig. BlendTree controls transitions among Walk / Run / Idle / Sit / Sleep / Jump / Eat / Scratch / Stretch / Wash Face / Observe. Random Idle picks among N subtle idle clips. Animation Layer overlays expressions. **AnimationDriver** is reserved as a protocol method stub whose body is cross-delivered by **Phase 5** (D-007).

After Phase 4 closes, the fox exhibits expressive motion and exposes the IK-driven rig that Phase 5 picks up for Dock-placement / cursor-tracking.

---

## 2. Pre-known Deliverables (finalized)

- [`spec-001-blendtree.md`](spec-001-blendtree.md) — BlendTree (CrossFade, Blend1D, Blend2D, Layer).
- [`spec-002-ik-four-variants.md`](spec-002-ik-four-variants.md) — IK System: Two-Bone (ears), CCD (tail), Foot (fore + hind legs), Look-At (head + eyes). Per **D-012**.
- [`spec-003-random-idle.md`](spec-003-random-idle.md) — Random Idle picker; consumes Phase-1 `AnimationClip` (D-004).
- [`spec-004-animation-driver.md`](spec-004-animation-driver.md) — **Signature-only** `AnimationDriver` protocol — `apply(offset: SIMD3<Float>, to: Bone.ID)`; Phase 5 fills body (D-007). Mandatory D-003 reservation.

---

## 3. IK Scope (D-012 — locked)

| IK Type | Applied To | Upstream Input |
|---|---|---|
| Two-Bone IK | Ears | Phase-3 `EarSpring.rotation` |
| CCD IK | Tail chain | Phase-3 `TailSpring.currentAngle` |
| Foot IK | Fore-legs + hind-legs | Phase-5 ground topology (Phase 4 ships a no-op target — see `spec-002` §2) |
| Look-At IK | Head + Eyes | Phase-5 cursor / Phase-6 emotion target |

Phase-4 ships the **algorithms** for all four IK types. Wiring Foot-IK to actual ground topology is Phase-5's concern (and is allowed to ship as no-op in Phase 4 per D-007-style protocol stub precedent).

---

## 4. Out of Scope (Phase 4)

- ❌ **Animation Driver implementation** — Phase 5 (cross-delivered per D-007). Phase 4 ships **signature only**.
- ❌ Behavior / Decision — Phase 6.
- ❌ Emotion-driven expression changes — Phase 6 (Phase 4 ships the Layer machinery, not the emotion source).
- ❌ Claude integration — Phase 7.
- ❌ IK on non-Quadruped additions (Tail props carrying objects) — Phase 6+.
- ❌ GPU-side skinning — Phase 2 (already shipped `SkinningPipeline` for Phase-1 stub; Phase 4 re-uses, not re-architects).
- ❌ Procedural walk on uneven terrain — Phase 5.

---

## 5. World Integration Reservation (D-003 / D-007 — mandatory)

Per **D-003 and D-007**, Phase 4 must expose the `AnimationDriver` signature:

```swift
protocol AnimationDriver {
    func apply(offset: SIMD3<Float>, to: Bone.ID)
    func reset(to bone: Bone.ID)
}
```

**Phase 4 ships the protocol only** — there is no concrete implementation in Phase-4 source tree. Per D-007, the real implementation is **cross-delivered by Phase 5** when Phase 5 wires up Dock / cursor tracking.

Acceptance at Phase-4 closure: protocol compiles, references in `Phase-4` source compile against signature, **zero** concrete `AnimationDriver` implementations exist in Phase-4 module — assertable via SwiftPM reflection test.

---

## 6. Risk (placeholder — to be expanded at Phase-4 kickoff)

- **4 IK solvers running per frame within 16 ms** — Mitigation: each solver's CPU-cost budget asserted in `spec-002` §5; P99 sum ≤ 1.5 ms.
- **BlendTree node explosion** — Mitigation: max node count hard-capped at 64; linter-level test asserts.
- **Random Idle variety vs visual coherence** — Mitigation: idle-pool curated by hand; entropy control ≤ 100 ms correlation window.
- **Animation Driver reservation must lock with Phase 5** — Mitigation: `spec-004-animation-driver.md` documents the signature surface explicitly; Phase-5 contract reads from this spec.
- **Foot-IK target no-op** in Phase 4 makes feet float on slopes during dev — Mitigation: explicit integration test asserts "Phase-4 Foot IK target is no-op until Phase 5 wires ground-topology source".

---

## 7. Acceptance (placeholder — 4-category form finalized in `acceptance.md`)

See [`acceptance.md`](acceptance.md) — three rows per Work Spec, plus a Phase-4 cumulative row.

Cumulative Phase-4 memory delta target: **≤ 6 MB** on top of Phase-3 baseline (≤ 142 MB worst-case at end of Phase-4).
Profiler `.everyFrame` overhead remains ≤ 0.5 ms / frame (Phase-1 row 24).

---

## 8. Cross-References

- **Phase 1**: `spec-005-animation.md` (Channel / Skeleton / Sampling baseline; Phase-4 builds on).
- **Phase 2**: `spec-001-metal-renderer.md` (SkinningPipeline handed off from Phase-1 → re-used not re-architected).
- **Phase 3**: `spec-003-secondary-motion.md` (consumes `TailSpring.currentAngle` and `EarSpring.rotation` as IK inputs).
- **Phase 5a**: `Phase-5-DesktopWorld/overview.md` (consumes `AnimationDriver` signature, fills body per **D-007**).
- **Phase 6**: Behavior Layer / Emotion / Decision (consumes AnimationLayer surface from `spec-001`).
- **ADRs**: D-003, D-007, D-008, D-012, D-013.
