<!--
Status: Draft
Phase: 3 — Physics
Owner: TBD
Depends: spec-001-physics-engine.md (RigidBody + World)
Consumes into: Phase 4 spec-002-ik-four-variants.md (CCD Tail variant uses spring output)
-->

# SPEC-002 — Character Physics (Walk / Jump / Landing / Slope)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> "Character physics" is a focused subset of the physics engine: the fox torso is a single (or two) rigid body with a deliberately cosmetic controller. Not a generic character controller — just enough to make jump/landing/slope believable.

---

## 1. Goal

Provide a kinematic-dominant character controller so the fox walks, jumps, lands smoothly (no infinite bouncing), and respects slopes (walks up ≤ 35° ramp without sliding). The controller is *cosmetic*: it does not model foot-precise ground clamping; ground contact is handled by the Physics Engine.

After SPEC-002 ships, sending `controller.jump()` from a debug menu launches the fox vertically, lands within ≤ 6 frames of simulated bounce decay, and resumes rest at the same height.

---

## 2. Deliverables

- `DPPhysics.CharacterController`:
  - State: `grounded(Bool)`, `velocity`, `verticalImpulseAccumulator`.
  - Inputs (Phase-3 reserved inputs; Phase 5 wires real bridge): `applyJump()`, `setWalkDirection(SIMD3<Float>)`.
  - Behavior:
    - **Jump**: apply instant 5 m/s upward impulse + brief coyote-time window (≤ 80 ms).
    - **Landing**: on `contact` event, vertical velocity component multiplied by 0.0 + horizontal by 0.7 within ≤ 6 frames of decay.
    - **Slope**: walk direction is rejected proportionally above 35° (`rejection = clamp01((angle - 35) / 25)`); fox sticks at ≤ 35°.
- Integration with `PhysicsWorld` via a `Phase3PhysicsAdapter` registered as a `RuntimeModule`.
- **Hooks into World Integration Reservation** (D-003): the controller may construct a `ColliderDescriptor(layer: .edge)` as a sentinel ground-edge collider; this is *only* to satisfy the D-003 type compiles test. No actual edge-vs-window hit-test in Phase 3.
- **Tests** (TDD per D-002):
  - Unit: `controller.jump()` from rest → first frame body has vertical velocity = 5 m/s ± 5 %.
  - Unit: drop from 2 m height on a hard plane → frames-to-rest ≤ 6; final velocity vector magnitude ≤ 0.05 m/s.
  - Unit: walking up a 40° ramp → walk direction component along the slope is rejected to **0** (no fall-through).
  - Unit: `ColliderDescriptor(layer: .edge)` is constructable from inside the character controller (asserts D-003 symbol can be used anywhere in Phase-3).
  - Integration: 60-frame stress test (jump + land + walk in circles) → no NaN escape, no frame-time spike > 1 ms / frame.
- **API docs**: `api/character-physics-api.md` — input sequence, coyote-time, slope policy.

---

## 3. Out of Scope

- ❌ **Crouch / slide / ledge-grab** — out.
- ❌ **Slide / dash** — out.
- ❌ **Foot-IK ground adaptation** — Phase 4 spec-002 (Foot IK variant).
- ❌ **Walk-cycle animation driver** — Phase 4 (Blendtree + AnimationDriver).

---

## 4. Risk

- **Bounce decay tuning**: too quick = landing feels sticky, too slow = pogo — Mitigation: frames-to-rest target default is 6; configurable via DPFoundation.Config (`character.landingDecayFrames`).
- **Coyote-time abuse**: jump-after-walking-off-edge could feel "floaty" beyond 80 ms — Mitigation: coyote-time strictly bounded; test asserts: jump after > 100 ms in air is rejected.
- **Slope rejection on real-world topologies**: 35° cut-off works for flat floors; on a real desktop Dock (Phase 5) slope might be 90° → Mitigation: Phase-5 controller variant consumes the same protocol and overrides slope policy.
- **Character controller eating collision events meant for Phase-5 dock** — Mitigation: when controller's body collider `layer == .edge`, it never reads the hit-test result (Phase 5 owns hit-test). Phase 3 confirms result is dropped, not consumed.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- Character controller update cost ≤ 0.1 ms / frame CPU-time (tighter than Phase-1 row 24 since physics is one of two heaviest counters in Phase 3).
- Memory delta ≤ 0.5 MB on top of `spec-001`.
- No regression of overall Profiler `.everyFrame` budget.

### Enumerable use case

- Jump from 0 → first frame v_y = 5 m/s; landing velocity ≤ 0 within 6 frames.
- Coyote-time test: walk off edge at frame T, jump at T+5 (≤ 80 ms) → jump succeeds; same test at T+10 (> 100 ms) → jump rejected.
- Walk up 35° ramp: ascent speed matches horizontal input × cos(35°) within 5 %.
- Walk up 40° ramp: ascent speed **= 0** (rejected).
- Drop from 2 m height: bottom-out-after-decay speed ≤ 0.05 m/s; final posture intent = "stand".

### Assertable state

- `controller.grounded == false` after jump and until first-down collision; `grounded == true` after decay.
- Slope-rejection curve is **monotone decreasing** in slope angle (verified with a unit test on values 30°, 35°, 40°).
- `ColliderDescriptor(layer: .edge)` constructed by controller is discarded within the same tick — memory profile is unchanged vs not constructing.
- Coyote-time window strictly ≤ 80 ms — assertable as `phase3_config.character.coyoteMs == 80`.

### Previous-Phase regression

- Phase 1 + Phase 2 + `spec-001-physics-engine.md` Acceptance still pass.
- Phase-1 `dt` clamp re-asserted: `controller.update(dt:)` clamps input dt to `[1/240, 1/30]` if it receives a stray value.
