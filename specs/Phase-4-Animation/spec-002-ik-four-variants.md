<!--
Status: Draft
Phase: 4 — Animation
Owner: TBD
Depends: Phase 1 spec-005-animation.md, Phase 3 spec-003-secondary-motion.md
ADRs:   D-012 (IK Scope locked), D-008, D-013
-->

# SPEC-002 — IK System (Two-Bone / CCD / Foot / Look-At)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> Four IK solvers per **D-012**, applied to specific anatomical locations. All four algorithms ship in Phase 4; **Foot-IK target is no-op** until Phase 5 supplies the dynamic ground-topology source (per D-007 stub-precedent).

---

## 1. Goal

Provide four inverse-kinematics solvers with bounded CPU cost and deterministic convergence properties, so the fox exhibits Tail follow-through (CCD), ear twitch (Two-Bone), leg adaptation on slope (Foot), and head/eye pursuit (Look-At). After SPEC-002 ships, all four algorithms produce stable poses within their respective convergence budgets, and the integration of Foot-IK to the world is **signature-reserved only** with Phase 5 owning the connectivity.

---

## 2. Deliverables

- `DPAnimation.IK` (protocol):
  - `solve(target: SIMD3<Float>, chain: [Bone.ID], pose: inout Pose) -> Result`
- Four concrete solvers, **alphabetical** order:
  - `DPAnimation.TwoBoneIK`:
    - Input: 2 bones (root + tip) + target.
    - Convergence: **1 step** (analytical, no iteration).
    - Used for **ears**.
    - Reads from Phase-3 `EarSpring.rotation`.
  - `DPAnimation.CCDIK`:
    - Input: chain length 4..12 (tail), target offset.
    - Convergence: ≤ 8 iterations; iteration count is configurable, default = 5.
    - Used for **tail**.
    - Reads Phase-3 `TailSpring.currentAngle`.
  - `DPAnimation.FootIK`:
    - Input: hind-leg + fore-leg chains; ground-topology target.
    - Foot-IK target resolution: Phase 3 default is **no-op** (target = current bone position). Phase 5 injects a real ground-topology source.
    - Convergence: 1 step analytical (terrain-following) — depends on target.
    - Test: assert `FootIK(target: = current position)` does not move the foot (the no-op case).
  - `DPAnimation.LookAtIK`:
    - Input: head + eye bones, target world point.
    - Convergence: ≤ 4 iterations; angular-priority smoothing to prevent snap.
    - Phase 4 default target: synthetic cursor (zero-vector), Phase 5 wires real cursor tracking.
- All IK solvers share `IK.maxIterations: Int = 5` (configurable per-solver).
- Tests:
  - Unit: Two-Bone IK (90° rotation) — solved angle is exactly 90° within 1e-4 rad.
  - Unit: CCD IK (target far away) — within ≤ 5 iterations, chain tip reaches within 1 cm of target.
  - Unit: Foot IK with no-op target — foot pose = current pose (no displacement).
  - Unit: Look-At — head orientation quaternion aligns with target direction within 5° angular error.
  - Integration: All 4 IK solvers run sequentially on a 41-bone rig — total CPU ≤ 1.5 ms / frame.
- **API docs**: `api/ik-four-variants-api.md` — convergence formulas, iteration budgets, input source per solver (especially the no-op default).

---

## 3. Out of Scope

- ❌ **Real Foot-IK ground target** — Phase 5.
- ❌ **Real Look-At cursor** — Phase 5.
- ❌ Dynamic multi-link Look-At (full spine tracking) — out.
- ❌ FABRIK / analytical-CCD hybrid — out.
- ❌ Constraint solving across multiple chains (e.g. both arms) — out.

---

## 4. Risk

- **CCD overshoot oscillation** — Mitigation: `tolerance` parameter caps iteration count when residual < 0.5 cm.
- **Foot-IK no-op leaking into the visual** — Mitigation: explicit assertion that `FootIK.solve` with `target = currentPosition` is the Phase-4 default; Phase-5 review must verify no `target` injection at Phase-4 closure.
- **Look-At snap at direction singularity** (target directly behind) — Mitigation: angular-priority smoothing introduces up to 60 ms ease-out — flag this in the API doc.
- **Solver cost stacking** — Mitigation: IK tick is bound by `RK4Budget.us` which wraps total IK time per frame (asserted ≤ 1 ms).
- **Two-Bone degeneracy** when joint angles are colinear — Mitigation: guard against zero-length mid bone; assertable test.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- Per-frame IK cost sum (4 solvers): P99 ≤ 1.5 ms on M2.
- Two-Bone: ≤ 0.05 ms / solve (analytical, ≤ 1 step).
- CCD: ≤ 0.6 ms / solve (5 iterations on a 6-link tail).
- Foot-IK no-op: ≤ 0.01 ms / solve (early-return).
- Look-At: ≤ 0.4 ms / solve (4 iterations).
- Profiler `.everyFrame` overhead unchanged.

### Enumerable use case

- Two-Bone: ear with root at (0,0,0), tip at (0,0.3,0), target at (0,0.3,0.3) — final ear-tip exactly at target within 1e-4.
- CCD: 6-link tail starting at (0,0,0); target at (1,1,0); converges within 5 iterations to within 1 cm of target.
- Foot-IK no-op: foot pose unchanged from input pose (delta ≤ 1 UM).
- Look-At: head bone rotates to face world point (0,1,0) from origin — orientation's forward vector angle to (0,1,0) ≤ 5°.
- All four on a 41-bone rig: cumulative CPU spend ≤ 1.5 ms / frame on M2.

### Assertable state

- `IK.maxIterations` config immutable per solver type — solver default exposed.
- Foot-IK no-op mode is the `init()` default — assertable via `FootIK().solve(target:)` test.
- Look-At angular-priority smoothing reaches `α ≤ 0.05` within ≤ 4 iterations.
- Cross-solver determinism: same target + same pose + same iterations → FP-bit identical pose output.

### Previous-Phase regression

- Phase 1 + Phase 2 + Phase 3 + Phase-4 `spec-001` Acceptance still pass.
- Phase-1 Sampling / Slerp semantics unchanged.
- Profiler `.everyFrame` overhead unchanged from Phase-3 baseline.
