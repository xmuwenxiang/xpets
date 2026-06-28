<!--
Status: Draft
Phase: 3 — Physics
Owner: TBD
Depends: spec-001-physics-engine.md
Consumes into: Phase 4 spec-002-ik-four-variants.md (CCD Tail variant)
-->

# SPEC-003 — Secondary Motion (Tail / Ear Spring-Damping)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> "Cute" wins over realistic. Spring constants are tuned for animation-friendly response, not engineering realism. This spec is the consumer-side input for the Phase-4 CCD Tail IK variant (D-012).

---

## 1. Goal

Inject secondary motion into the fox's tail and ears so they react to torso acceleration with damped delay, producing the lifelike "follow-through" effect Disney-Physics prescribes. Output of the spring simulation is exposed as a per-bone force/position target consumed downstream by Phase-4 CCD Tail IK.

After SPEC-003 ships, snapping the fox's torso horizontally triggers a tail swing that lasts 0.6 - 1.2 s before settling, and dampens without oscillation overflow.

---

## 2. Deliverables

- `DPPhysics.SpringSimulation`:
  - Generic over `SIMD3<Float>`-valued endpoints.
  - State per joint: `position`, `velocity`, `targetPosition`, `springConstant`, `damping`.
  - `step(dt:)` integrates semi-implicit Euler — stable up to 1/30 s.
  - Final position emitted as `proposedDelta` for downstream bone application.
- Configurations (defaults; tunable in `DPFoundation.Config`):
  - **Tail**: stiffness `k = 220 N/m`, damping `c = 6 N·s/m`. Target swings ± 25° per torque event.
  - **Ear**: stiffness `k = 95 N/m`, damping `c = 4 N·s/m`. Target rotation tracks head-look direction with phase-lag ≤ 120 ms.
- Public hooks to query per-step simulation result:
  - `tailSpring.currentAngle:` exposed read-only; consumed by **Phase-4 spec-002-ik-four-variants.md** (CCD).
  - `earSpring.rotation:` same.
- Subsystem integration:
  - Subscribes to Phase-1 `Runtime.tick(dt:)` at a sub-step granularity (`internalSubSteps = max(1, floor(dt * 240))`).
  - Does NOT call into `DPRenderer`.
- **Tests** (TDD per D-002):
  - Unit: tail-spring step with target shift 0 → 25° at t=0 settles to within 0.5° of target within 1.2 s, with overshoot ≤ 15 %.
  - Unit: ear-spring step with target shift 0 → 90° within 100 ms — settling within 0.3 s, overshoot ≤ 10 %.
  - Stability: 100 simulated seconds at 60 FPS with constant target — `position.isFinite` always true (no NaN); max-stored position ≤ 2.0 rad.
  - Sub-stepping: dt = 1/15 → Simulation still stable (driver does at least 2 internal substeps).
- **API docs**: `api/secondary-motion-api.md` — config surface, sub-step formula, downstream consumer points (Phase-4 CCD).

---

## 3. Out of Scope

- ❌ **Hair / fur / cloth simulation** — out per Phase-3 §3.
- ❌ **Multi-spring coupling** (tail-rotate-influences-ear) — out; each spring runs independently.
- ❌ **Volume preservation / collision** of secondary motion — spring-only.
- ❌ **External wind force** — out.
- ❌ **GPU compute spring** — CPU-side is sufficient for ≤ 6 springs total.

---

## 4. Risk

- **Sub-step granularity is wrong on slow frames** — Mitigation: `floor(dt * 240)` is the formula. Test asserts dt = 1/15 runs ≥ 2 internal substeps.
- **Stiffness tuning makes the fox look "rubbery"** — Mitigation: defaults are conservative. Owner can re-tune via `DPFoundation.Config` at runtime; tests assert default behavior matches Disney-style response, not engine-style realism.
- **Spring simulation eating CPU budget** — Mitigation: maximum of 6 springs (1 tail + 2 ears + 3 reserve). Cost is ≤ 50 µs / sub-step.
- **Phase-4 IK chain reads stale spring angle** — Mitigation: `tailSpring.currentAngle` is computed synchronously and exposed at the same synchronization point; tests assert angle update happens before any reader call (no race).
- **Spring constants inadvertently exposed in units the integrator can't handle** — Mitigation: API exposes `springConstant: Float`, integrator handles internally; unit mismatch is caught at compile time.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- `SpringSimulation.step(dt:)` cost ≤ 50 µs / sub-step on M2 with 6 springs active.
- CPU-time per Phase-1 tick ≤ 0.15 ms reserved (sub-stepped at 4 substeps for 60 FPS).
- Memory delta ≤ 1 MB on top of `spec-001` + `spec-002`.

### Enumerable use case

- Torso +1 m horizontal thrust at t=0 → tail spring settles within 0.6-1.2 s with overshoot ≤ 15 % (3 repeated runs).
- 100 s stress soak with random target shuffling → no NaN, no position > 2.0 rad (assertable in test).
- Sub-step granularity: dt = 1/15 → ≥ 2 internal substeps, output equivalent to dt = 1/30 × 2.
- Phase-4 reader (mocked read by Phase-3 test): `tailSpring.currentAngle` reaches within 0.01 rad of `targetAngle` after settling time.

### Assertable state

- `SpringSimulation.step(dt:)` is `Sendable`-safe — sub-stepping across Physics and Animation threads is not allowed (single thread).
- After `step(dt:)`, the simulation's state must be deterministic: same target + same dt → same final state (FP-bit exact).
- `overshoot <= 1.15 * targetMagnitude` is the explicit upper bound on overshoot — assertable.

### Previous-Phase regression

- `spec-001-physics-engine.md` Acceptance still pass — SpringSimulation **does not** allocate new bodies, just runs on dedicated CPU slots.
- Phase-1 + Phase-2 Acceptance still pass.
- Profiler `.everyFrame` overhead ≤ 0.5 ms / frame — Phase-3 spring emits at most one `Counter` per Phase-1 tick.
