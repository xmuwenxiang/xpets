# Phase 5 — Acceptance

> Phase-5 closure Acceptance in 4-category form per D-013. Distilled from each Work Spec's §5 plus the Phase-level cumulative rows.

---

## A. By Work Spec

### A.1 SPEC-001 Desktop Discovery (5a)

| Category | Item |
|---|---|
| Performance | Snapshot refresh ≤ 16 ms at 60 FPS / ~100 entities |
| Performance | Snapshot throttle ≤ 1 Hz; deltas bypass throttle |
| Performance | Memory delta ≤ 3 MB |
| Enumerable | 10 synthetic entities → 10 added events |
| Enumerable | 1 entity update → 1 updated event |
| Enumerable | 1 entity removal → 1 removed event |
| Enumerable | 60 ticks in 1 s → exactly 1 snapshot |
| Enumerable | Permission denied: `isAuthorized == false`, empty entities |
| Assertable | `Entity.id` deterministic across catalog re-runs |
| Assertable | `visibilityClass` defaults to `.public`; private/sensitive settable |
| Assertable | `Sendable` snapshot thread-safety for read path |
| Regression | Phase 1..4 Acceptance still pass; Profiler budget unchanged |

### A.2 SPEC-002 World Rendering Route (5a)

| Category | Item |
|---|---|
| Performance | Config storage ≤ 64 bytes; one-shot at boot |
| Performance | Memory delta ≤ 0.1 MB |
| Enumerable | Boot with default `DPFoundation.Config.defaultWorldRoute = .singleRenderer` |
| Enumerable | Override `config.worldRoute = .dualRenderer` → `Renderer.worldConfig.route == .dualRenderer` |
| Enumerable | `.nativeCapture` override works |
| Enumerable | Mutating config after boot throws `RendererError.configImmutable` |
| Assertable | `WorldRenderingRoute` exhaustive `enum` |
| Assertable | `Renderer.worldConfig` is `let` |
| Assertable | `WorldRenderingRouteConfig` is `Codable` |
| Regression | Phase 1..4 Acceptance still pass; Phase-2 Renderer untouched |

### A.3 SPEC-003 World Events (5b)

| Category | Item |
|---|---|
| Performance | Debounce flush latency P99 ≤ 110 ms (WindowChange) |
| Performance | Per-frame emission cost ≤ 50 µs |
| Performance | Memory delta ≤ 1 MB |
| Enumerable | 30 WindowChange in 50 ms → exactly 1 debounced event |
| Enumerable | 4 screen-parameter changes in 100 ms → 1 ScreenChange event |
| Enumerable | Subscription cancel: token-deallocated handlers receive 0 events |
| Assertable | `WorldEventBus` thread-safe |
| Assertable | Debounce policy is per-event-type |
| Assertable | Token cancellation is one-way |
| Regression | Phase 1..4 Acceptance still pass |

### A.4 SPEC-004 Desktop World (5b)

| Category | Item |
|---|---|
| Performance | NavMesh path query ≤ 0.4 ms P99; full rebuild ≤ 16 ms P99 |
| Performance | `Phase5AnimationDriver.apply` queue ≤ 5 µs / call |
| Performance | Cumulative Phase-5 ≤ 12 MB delta on Phase-4 baseline |
| Performance | Profiler budget unchanged |
| Enumerable | `path(.zero, (10, 0))` returns ≥ 4 waypoints |
| Enumerable | 1 WindowChange → NavMesh ≤ 16 ms rebuild |
| Enumerable | 60-frame NavMesh soak → no frame > 16 ms |
| Enumerable | `apply(offset:(0.1,0,0), to: 0)` produces non-zero Bone matrix delta |
| Enumerable | `reset(to: 0)` clears pending offset |
| Enumerable | `DockHop(world:)` transitions fox toward Dock within 6 frames |
| Enumerable | `registerPhase5EdgeBridge(Phase5EdgeBridge())` replaces `.noop` with real bridge |
| Assertable | NavMesh deterministic: same entity set → same path |
| Assertable | Phase-5 owns AnimationDriver conformer reflection (NOT Phase-4) |
| Assertable | Phase-3 `phase3_world_reservation_compiles` continues to pass |
| Assertable | `WindowVisibilityPolicy` enum: public/private/sensitive compile-visible |
| Regression | Phase 1..4 Acceptance still pass; Animator.tick semantics unchanged |

---

## B. Phase-5 Cumulative Row

| Category | Item |
|---|---|
| Performance | Profiler `.everyFrame` overhead ≤ 0.5 ms / frame (Phase-1 row 24, re-asserted) |
| Performance | Cumulative Phase-5 memory delta ≤ 12 MB on top of Phase-4 baseline |
| Performance | Total runtime memory worst-case ≤ **154 MB** (Phase 4 142 + Phase 5 12) |
| Enumerable | All SPEC-001..SPEC-004 §5 acceptance items pass |
| Assertable | D-005 5a/5b split locked (decision documented in `spec-002`) |
| Assertable | D-007 — Phase-5 owns AnimationDriver conformer count > 0; Phase-4 conformer count remains 0 |
| Assertable | D-003 — Phase-3 `phase3_world_reservation_compiles` continues to pass |
| Assertable | Phase-5 closure completes with `checklist.md` fully checked |
| Regression | All Phase 1..4 `acceptance.md` items pass at end of Phase 5 |

---

## C. D-007 Cross-Deliverable Proof

Phase 5 closes the D-007 obligation: Phase 4 ships *signature only*; Phase 5 ships the *implementation*. At Phase-5 closure, a reflection test asserts:

| Module | Expected conformer count for `AnimationDriver` |
|---|---|
| `DPRuntime` (Phase-1) | 0 |
| `DPAnimation` (Phase-2 + 4 source) | 0 (signature only) |
| `DPMain` (Phase-5 source) | ≥ 1 (`Phase5AnimationDriver`) |

This test must pass for Phase-5 to close.

---

## D. Per-D-005 5a/5b Audit

| Sub-Phase | Work Specs | D-005 Lane |
|---|---|---|
| 5a | `spec-001-desktop-discovery.md`, `spec-002-world-rendering-route.md` | Frozen decision tree (`Single` / `Dual` / `Native-Capture`) |
| 5b | `spec-003-world-events.md`, `spec-004-desktop-world.md` | Container + NavMesh + Pet interaction + D-007 cross-deliverable |
