<!--
Status: Draft
Phase: 5b — DesktopWorld
Owner: TBD
Depends: spec-001-desktop-discovery.md, spec-002-world-rendering-route.md, spec-003-world-events.md, Phase 3 spec-004-world-reservation.md, Phase 4 spec-004-animation-driver.md
ADRs:   D-003 (consume Phase 3 reservation), D-005, D-007 (cross-deliver AnimationDriver implementation), D-008, D-013
-->

# SPEC-004 — Desktop World (Container / NavMesh / AnimationDriver Implementation)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> Phase 5b is the **vertical integration moment**. After SPEC-004 ships, the fox is a 3D actor living on the desktop, breathing through Spring + IK + AnimationDriver.

---

## 1. Goal

Bring up the **Container**, the **NavMesh** that maps desktop topology, **Pet interactions** (hop-onto-Dock, walk-around-icons, peek-into-Finder), and most importantly **the real AnimationDriver implementation** (D-007 cross-deliverable) — i.e. the gap between Phase-4 signature and Phase-5 real. After SPEC-004 ships, the fox moves between Dock and desktop; the `AnimationDriver.apply(offset:to:)` traces through to actual bone offsets in D-012's IK variants.

---

## 2. Deliverables

- **`DPDesktop.DesktopWorld`**:
  - Owns the entity catalog subscription (via `spec-003`).
  - Owns the foot-IK target source: a function `(Bone.ID) -> SIMD3<Float>?` looking up the ground-topology beneath the bone, by querying the catalog for the closest entity with `.collisionLayer == .defaultLayer` and using its `bounds.minY`.
  - Owns the LookAt-IK target source: a function `(Bone.ID) -> SIMD3<Float>?` for head/eye bones; uses the cursor position from `NSEvent.mouseLocation`.
  - Owns the NavMesh; **rebuilds incrementally on `WindowChange`** events (debounced 100 ms).
- **`DPDesktop.NavMesh`**:
  - Surface-sampled from active windows + dock topology.
  - 2D polyline representation with steering hints (`preferredDirection`, `costPerEdge`).
  - Path query: `path(from: SIMD2<Float>, to: SIMD2<Float>) -> [SIMD2<Float>]`.
  - Properties: query latency ≤ 0.4 ms / query, ≤ 16 ms full rebuild at 60 FPS for ≤ 100 entities.
- **`DPDesktop.WorldInteraction`**:
  - `DockHop(world:)` — moves the fox from current location onto Dock top surface.
  - `PeekIntoWindow(windowID)` — moves fox cursor (LookAtIK target) to follow a window boundary.
  - All interactions are *non-intrusive* — they do NOT change the user's macOS UI state.
- **`DPAnimation.Phase5AnimationDriver`** (the D-007 cross-deliverable):
  - Conforms to the Phase-4 `AnimationDriver` protocol.
  - Concrete implementation: `apply(offset:to:)` reads from the Phase-5 `DesktopWorld`; if `offset == 0`, no-op; otherwise, queue the bone transformation for the next Phase-1 `Animator.tick(dt:)`.
  - `reset(to:)` clears the offset queue for the bone.
- **`DPDesktop.WindowVisibilityPolicy`**:
  - Phase-5 ships *the data model*; the mapping is Phase 6.
  - `class { public, private, sensitive } supported.
- **Tests** (TDD per D-002):
  - Unit: `NavMesh.path(from:.zero, to: (10, 0))` returns at least 4 waypoints.
  - Unit: incremental rebuild: 1 WindowChange → NavMesh updated ≤ 16 ms.
  - Unit: `Phase5AnimationDriver.apply(offset: (0.1, 0, 0), to: Bone.ID 0)` produces a non-zero Bone matrix delta in the next animator tick.
  - Unit: `Phase5AnimationDriver.reset(to: Bone.ID 0)` clears pending offset.
  - Integration: `DockHop(world:)` produces a phase-3 SpringSimulation input via the controller; fox position is transitioning toward Dock.
  - Integration: `LookAtIK.target` from cursor world-position is non-zero when cursor is at a non-origin point.
  - Phase-3 reservation **resolved**: `registerPhase5EdgeBridge(Phase5EdgeBridge())` replaces `.noop`; the new bridge emits real `.dock | .window` hit-test results.
  - Privacy visibility: entity with `.visibilityClass == .sensitive` does NOT contribute to OCR-able surfaces (assertable; OCR is forbidden at Phase-5 level).
- **API docs**: `api/desktop-world-api.md` — World container, NavMesh, AnimationDriver cross-reference (Phase-4 signature), privacy contract shell.

---

## 3. Out of Scope

- ❌ **Behavior / decisions** — Phase 6 (where to walk, when to hop on Dock).
- ❌ **Emotion-driven interaction** — Phase 6.
- ❌ **Claude integration** — Phase 7.
- ❌ **OCR of any window** — Phase 5 forbids OCR at any level.

---

## 4. Risk

- **Pathfinding on dynamic topology** — Mitigation: NavMesh rebuild bounded ≤ 16 ms; tests assert 60-frame soak stays under budget.
- **DockHop interfering with mouse events** — Mitigation: Pet's interaction is **cursor-puppet** only (changes LookAtIK target); it does NOT call `NSWindow.makeKey()` or similar APIs.
- **AnimationDriver implementation drift from Phase-4 signature** — Mitigation: spec-004 root-test asserts Phase-5 conformer passes the cross-Phase functional test defined by Phase-4 spec-004 §5 + this spec §2.
- **Phase-3 bridge mis-integration** — Mitigation: reflection test asserts `Phase5EdgeBridge` is the registered bridge at end-of-Phase-5; the Phase-3 `phase3_world_reservation_compiles` test continues to pass.
- **GPU cost of NavMesh rebuild** — Mitigation: rebuild is CPU-side; GPU consumes via texture upload (≤ uint32 per vertex).
- **Pet occupying an area where the user is typing** — Mitigation: `DockHop.request()` may be denied if the entity has `visibilityClass == .sensitive`; this is the Phase-6 Privacy mapping, the contract is established here.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- NavMesh path query ≤ 0.4 ms P99.
- Full NavMesh rebuild P99 ≤ 16 ms with ≤ 100 entities.
- `Phase5AnimationDriver.apply(offset:to:)` queue cost ≤ 5 µs / call.
- Cumulative Phase-5 memory delta ≤ 12 MB on top of Phase-4 baseline (target ≤ 160 MB worst-case at end-of-Phase-5).
- Profiler budget ≤ 0.5 ms / frame unchanged.

### Enumerable use case

- `path(from:.zero, to: (10, 0))` returns ≥ 4 waypoints cumulative covering the lattice.
- Incremental rebuild on 1 WindowChange completes in ≤ 16 ms.
- 60-frame soak at NavMesh under traffic — no frame exceeds 16 ms.
- `apply(offset: (0.1, 0, 0), to: Bone.ID 0)` — next `Animator.tick(dt:)` produces a measurable Bone matrix delta.
- `reset(to: 0)` clears pending offset → next tick produces zero delta.
- `DockHop(world:)` transitions fox toward Dock within 6 frames.
- `registerPhase5EdgeBridge(Phase5EdgeBridge())` → 1 successful `resolveEdgeHit` returns `.dock` or `.window` (was `.noop` in Phase 3, now real).

### Assertable state

- `NavMesh` is deterministic: same entity set → same path for same endpoints (FP-bit identical).
- `Phase5AnimationDriver` is the only concrete conformer in `Phase-5` module's reflection (`allConformingTypes(in: DPMain.self)` includes Phase-5 conformers, NOT Phase-4-owned ones).
- `Phase-3` allowed: `Collider(layer: .edge)` works as Phase-3 acceptance; Phase-5 implementation answers correctly.
- Privacy contract: `WindowVisibilityPolicy` is a typed enum exposed public; private / public / sensitive are visible at compile-time.

### Previous-Phase regression

- Phase 1..4 `acceptance.md` items still pass.
- Phase-3 `phase3_world_reservation_compiles` test continues to pass.
- Phase-4 `phase4_animation_driver_signature_compiles` test continues to pass; the **conformance count changes** (Phase-5 adds conformers).
- `DPAnimation.Animator.tick` semantics unchanged.
- Profiler `.everyFrame` ≤ 0.5 ms.
