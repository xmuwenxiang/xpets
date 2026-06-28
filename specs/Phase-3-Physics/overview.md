<!--
Status: Drafts authored (2026-06-28)
Phase: 3 — Physics
Owner: TBD
ADRs:  D-003 (World Integration Reservation — Collider-Edge), D-008 (Profiler budget), D-012 references Phase 4 IK Scope, D-013 (4-category Acceptance)
-->

# Phase 3 — Physics

> **Status**: Stub → **Drafts authored (2026-06-28)**. Four Work Specs now exist at Apple Style + 4-category Acceptance; implementation gated on owner review + `Status: Approved`.
> **Goal**: Integrate Jolt Physics. Add Gravity, Collision, Spring (Tail), Ear spring, Head Tracking. Verify the fox jumps / lands / tail wags / ears swing.
> **Primary Output**: A physics-driven fox with Disney-Physics fidelity (cute over physically absolute).

> Per **D-003**, this Phase **MUST carry a World Integration Reservation** — see [`spec-001-physics-engine.md`](spec-001-physics-engine.md) §2 + the dedicated `spec-004-world-reservation.md`.

---

## 1. Goal (Phase 3 final)

A runtime physics simulation grounded in Jolt / equivalent solver. The fox is a kinematic-friendly actor with a configurable collider, a tail spring, and a gravity-aware body. Simulation runs deterministically per `tick(dt:)` and respects the Phase-1 `dt ∈ [1/240, 1/30]` invariant.

After Phase 3 closes, the fox can be launched in a stress-test "world" (a flat plane) and respond with believable physical consequences — no NaN escapes, no-zero-gravity, no inertia accumulation over 60 s.

---

## 2. Pre-known Deliverables (finalized)

- [`spec-001-physics-engine.md`](spec-001-physics-engine.md) — Jolt World, RigidBody, Constraint, Collision, Gravity. **Hosts the World Integration Reservation in §2** (D-003).
- [`spec-002-character-physics.md`](spec-002-character-physics.md) — Walk, Jump, Landing, Slope, Obstacle.
- [`spec-003-secondary-motion.md`](spec-003-secondary-motion.md) — Tail, Ear spring / damping. Drives one CCD IK chain in Phase 4 (D-012).
- [`spec-004-world-reservation.md`](spec-004-world-reservation.md) — `<-` dedicated **Phase 5 hook reservation** spec (mandatory per D-003): `Collider.collisionLayer` extension to `.edge`.

---

## 3. Out of Scope (Phase 3)

- ❌ **Physics-based hair / cloth** — even fox fur is rigged, not cloth-sim.
- ❌ **Fluid / SPH** — out per design.
- ❌ **Destructive physics** — out per design.
- ❌ **Vehicle / Character Controller 3rd-party patterns** — out per design.
- ❌ **Animation richness** — Phase 4 (Blendtree, IK).
- ❌ **Desktop World integration** — Phase 5. NOTE: Phase 3 reserves the collider-edge *interface* but the implementation lands in Phase 5.
- ❌ **Behavior / AI** — Phase 6 / 7.

---

## 4. World Integration Reservation (D-003 — mandatory)

Per **D-003**, Phase 3 must carry the following forward-looking reservation:

- `Collider.collisionLayer` MUST support a `Layer.edge` value **alongside** any current layered-bitmask scheme.
- Phase 3 ships the *type-level extension*; full edge-vs-Dock / edge-vs-window detection is implemented in Phase 5a.
- A `phase3_world_reservation_compiles.swift` test asserts the type compiles, an `Collider(layer: .edge)` instance can be constructed and discarded without crashing.
- `api/physics-api.md` documents `Layer.edge` as Phase-5-facing publicly.

Phase 3 must NOT implement Phase 5's dock / window hit-tests — only reserve the data type.

---

## 5. Risk (placeholder — to be expanded at Phase-3 kickoff)

- **Jolt ↔ Swift bridge ABI stability on Apple Silicon** — undefined-package surface, Mitigation: wrap all Jolt calls behind a Swift protocol so we can swap to Bullet / custom if Jolt binary drops support.
- **Spring tuning for "cute" vs "realistic"** — Mitigation: `SpringConfig` exposes stiffness / damping as Swift-level constants tunable at runtime via `DPFoundation.Config`.
- **Coordinate mapping between Jolt World and Metal Renderer** — Mitigation: Phase-1 `Renderer` owns the camera transform; physics returns world-space; renderer takes care of conversion. Tested in integration.
- **Overlap with Phase 5a Collider-Edge hook contract** — Mitigation: `spec-004-world-reservation.md` documents the bridge surface; Phase 5a refines it.

---

## 6. Acceptance (placeholder — 4-category form finalized in `acceptance.md`)

See [`acceptance.md`](acceptance.md) — three rows per Work Spec, plus a Phase-3 cumulative row.

Cumulative Phase-3 memory delta target: **≤ 4 MB** on top of Phase-2 baseline (≤ 132 MB worst-case at end of Phase-3).
Profiler `.everyFrame` overhead remains ≤ 0.5 ms / frame (Phase-1 row 24 regression — physics must NOT emit `Counter` more than once per `dt`).

---

## 7. Cross-References

- **Phase 1**: `spec-003-runtime.md` (dt gate, Runtime tick ownership), `spec-006-profiler.md` (`Counter` interface for P99 budget).
- **Phase 2**: `spec-001-metal-renderer.md` (Renderer thread ownership — physics must NOT touch GPU).
- **Phase 4**: `spec-002-ik-four-variants.md` (CCD Tail uses Phase-3 spring output as input curve).
- **Phase 5a**: `Phase-5-DesktopWorld/overview.md` (consumes `Layer.edge` reservation; refines hook contract).
- **ADRs**: D-003 (mandatory), D-008, D-012 (tail ↔ CCD IK variant), D-013.
