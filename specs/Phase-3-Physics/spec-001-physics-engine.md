<!--
Status: Draft
Phase: 3 — Physics
Owner: TBD
Depends: Phase 1 spec-003-runtime.md (dt gate), Phase 1 spec-006-profiler.md (Counter)
Implements chains: ADRs D-003 (World Integration Reservation), D-008, D-013
-->

# SPEC-001 — Physics Engine (Phase 3 backbone)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> The Physics Engine is the Phase-3 backbone: World + Step + Body API. The **World Integration Reservation lives in §2** of this spec (Phase-5-vs-Phase-3 boundary is here, not in `spec-004` — `spec-004` is a focused re-statement for reviewers).

---

## 1. Goal

Provide a Swift facade over the Jolt physics solver that exposes a deterministic, fixed-timestep physics World, with RigidBody / Constraint / Collider value types, integrated into Phase-1 Runtime's `tick(dt:)` callback. The Engine is wrapped behind a Swift protocol so the underlying solver is swappable.

After SPEC-001 ships, calling `physics.world.step(dt:)` advances all bodies, applies gravity, complains about NaN escapes, and reports stable P99 step-time under `≤ 0.8 ms / frame` at 60 FPS on Apple Silicon.

---

## 2. Deliverables

- `DPPhysics.PhysicsEngine` protocol:
  - `var world: PhysicsWorld { get }`
  - `func step(dt: Double)  // MUST respect Phase-1 dt clamp [1/240, 1/30]`
- `DPPhysics.PhysicsWorld`:
  - `func addBody(_ body: RigidBody) -> BodyHandle`
  - `func removeBody(_ handle: BodyHandle)`
  - `func setGravity(_ g: SIMD3<Float>)`
  - `step(dt:)` propagates callers.
- `DPPhysics.RigidBody` value type:
  - `position, orientation, linearVelocity, angularVelocity, mass, friction, restitution`.
  - `collider: ColliderDescriptor` (carries `Collider.collisionLayer` — see below).
- `DPPhysics.Collider`:
  - `enum CollisionLayer { case defaultLayer, edge }` — **Phase-3 reservation must coexist** with any bitmask scheme.
  - `ColliderDescriptor { shape, layer, isSensor, ... }`.
  - **Locked invariant**: `ColliderDescriptor(layer: .edge)` is a valid public symbol; can be constructed and discarded.
- `DPPhysics.BodyHandle` opaque pointer-equality handle; Phase-3 ships `Equatable` semantics backed by Jolt BodyID.
- **`Doesn't-touch-GPU` invariant**: PhysicsEngine never calls into `DPRenderer.Renderer`. Test: importing `DPRenderer` from a physics-incrementing module triggers a compile error caught by SwiftPM target boundary.
- **Tests** (TDD per D-002):
  - Unit: rigid body with gravity 9.8 over 1 frame falls a known distance (within 5 % tolerance).
  - Unit: `ColliderDescriptor(layer: .edge)` compiles + survives construction + discard without crash.
  - Unit: NaN velocity injection triggers recovery (`body.reset()`) and the world keeps running.
  - Integration: 1000 bodies in a vertical stack settle within 60 frames with zero NaN escape (asserted via `simd_reduce_max`).
- **API docs**: `api/physics-api.md` — protocol surfaces, threading contract (Physics runs on the same thread as Runtime tick).

---

## 3. Out of Scope

- ❌ Character controller (jump / land) — `spec-002-character-physics.md`.
- ❌ Spring / secondary motion (tail, ear) — `spec-003-secondary-motion.md`.
- ❌ Phase-5 desktop-edge hit-test — `spec-004-world-reservation.md` is reservation only; Phase 5a implements.
- ❌ Multi-solver (Bullet, PhysX) — protocol surface supports swap, but only Jolt is shipped.
- ❌ **GPU physics / compute pass** — explicitly out of Phase 3 (and Phase 2 Renderer architecture).

---

## 4. Risk

- **Jolt ↔ Swift bridge ABI stability on Apple Silicon** — Mitigation: keep all Jolt calls behind the Phase-8 protocol facade; we never expose raw Jolt headers.
- **NaN / Inf escape under large cumulative forces** — Mitigation: `body.reset()` recovery is automatic; a `Counter(name: "physics.nan_escape")` is emitted per escape.
- **dt clamp interaction** — Phase-1 clamps to `[1/240, 1/30]`; passing in 68 ms by accident causes physics to overstep → Mitigation: World-owned `step(dt:)` re-clamps internally.
- **`Layer.edge` reserved but unused** may ship as a no-op collision target — Mitigation: `layer == .edge` always passes its hit-test to a "Phase 5 handler" stub that returns nil in Phase 3; Phase 5 wires the real hit-test.
- **Solver-determinism drift on changes to threading model** — Mitigation: Physics runs on the same thread as Runtime tick; tests assert `currentThread` matches `Runtime.currentThreadID` at the start of `step(dt:)`.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- `World.step(dt:)` P99 ≤ 0.8 ms / frame at 60 FPS on macos-14 / M2 with 12 bodies.
- Memory delta introduced by SPEC-001 ≤ 2.5 MB on top of Phase-2 baseline (132 MB worst-case end-of-Phase-3).
- Solver Jolt → Swift call cost ≤ 30 µs / frame measured via `Profiler.Counter`.

### Enumerable use case

- 1 body with gravity 9.8 over 5 simulated seconds: falls 122.5 m within 5 % error.
- 12 bodies in a vertical stack (heaviest at bottom): settle within 60 frames; final velocity each body ≤ 0.05 m/s (at rest).
- NaN injection on body[3].linearVelocity: world logs `physics.nan_escape`, body[3] is reset to (0,0,0) with zero velocity, world continues to step; assert next frame no-NaN.
- Three sequential `Layer.edge` colliders created and destroyed: clean shutdown, no Jolt assertion failure.

### Assertable state

- `ColliderDescriptor(layer: .edge)` compiles and constructs (mandatory D-003 acceptance symbol).
- `BodyHandle == BodyHandle` value-equality (backed by Jolt BodyID) — assertable test.
- After `removeBody(handle)` the handle becomes `isValid == false`; calling `removeBody` again is a no-op (no crash).
- Physics Engine never imports `DPRenderer` — enforced via SwiftPM target boundary.

### Previous-Phase regression

- All Phase 1 + Phase 2 `acceptance.md` items still pass — re-run CI.
- Phase-1 `dt ∈ [1/240, 1/30]` clamp invariant re-asserted even when physics is loaded (simulator-style test sets `dt=0.07` and asserts Phase-3 world re-clamps it).
- Profiler `.everyFrame` overhead ≤ 0.5 ms / frame — physics emits exactly one `Counter` per frame (one tap at most).
