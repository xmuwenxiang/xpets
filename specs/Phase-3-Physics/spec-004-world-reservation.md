<!--
Status: Draft
Phase: 3 — Physics
Owner: TBD
Depends: spec-001-physics-engine.md (where ColliderDescriptor + CollisionLayer live)
Consumes next: Phase 5a (Phase-5-DesktopWorld) — refines hook contract + implements real edge detection
ADRs:  D-003 (mandatory)
-->

# SPEC-004 — World Reservation (Phase-5 Collider-Edge Hook)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> **This spec exists because D-003 makes a Phase-3 reservation mandatory.** It does NOT implement Phase 5's dock / window edge detection — it reserves the type-level extension and the cross-phase bridge surface so Phase 5a can build on it without changing Phase-3 surface contracts.

---

## 1. Goal

Document and expose (in Phase 3) the `Collider.collisionLayer.edge` extension plus a stub **Phase-5 Bridge protocol** whose implementation lands in Phase 5a. Phase 3 ships:
- the type-level symbols,
- the stub protocol,
- a no-op implementation of the bridge, returning `nil` for every `Layer.edge` hit-test,
- a `phase3_world_reservation_compiles` test asserting the symbols exist and are reachable.

After SPEC-004 ships, Phase 5a can replace the no-op with a real implementation **without** touching any other Phase-3 public API.

---

## 2. Deliverables

- **Already-shared surface** (lives in `spec-001-physics-engine.md`, listed here for review cohesion):
  - `Collider.CollisionLayer { case defaultLayer, edge }`.
  - `ColliderDescriptor(layer: .edge)` — publics usable in Phase 3 even though no implementation interprets it.
- **Phase-3-owned stub**:
  - `protocol Phase5EdgeBridge: AnyObject`:
    - `func resolveEdgeHit(handle: BodyHandle, at worldPoint: SIMD3<Float>) -> Phase5EdgeHitResult?`
    - `Phase5EdgeHitResult { kind: .dock | .window | .unknown, hitNormal, surfaceAnchor }`
    - **Phase-3 default implementation** is `Phase5EdgeBridge.noop` returning `nil`.
  - `DPPhysics.registerPhase5Bridge(_ bridge: Phase5EdgeBridge?)` — accepts nil to disable.
- Reserved integration points (do NOT implement now, but document):
  - `PhysicsWorld.step(dt:)` will call `phase5Bridge?.resolveEdgeHit(...)` after each step **once Phase-3 ships Phase-5 handle proxying**; in Phase 3 the call site is **commented out** with `// Phase-5 hookup point: enables when bridge sets are wired — see Phase-5a/.../spec-NNN-render-route.md`.
- **Tests** (TDD per D-002):
  - Compile: `ColliderDescriptor(layer: .edge)` constructs and discards without runtime error.
  - Compile: `Phase5EdgeBridge` admitted as a protocol type in Phase-3 module.
  - Runtime: `Phase5EdgeBridge.noop.resolveEdgeHit(...)` returns `nil`.
  - Runtime: `registerPhase5Bridge(.noop)` leaves World state unchanged.
- **API docs**: `api/world-integration-hook.md` — explicitly marked **Phase-5-facing public**; the doc says "Phase-3 only reserves; Phase-5 implements."

---

## 3. Out of Scope

- ❌ **Real dock / window hit-testing** — Phase 5a.
- ❌ **Window edge geometry sampling** (`NSScreen.frame` -> world transform) — Phase 5a.
- ❌ **Multi-display dock topology** — Phase 5b.
- ❌ **Phase-5 physics tuning for surface friction at edges** — Phase 5a.
- ❌ **Edge bridge hot-reload** at runtime — out of Phase 3 + Phase 5; not part of any Phase in `roadmap.md`.

---

## 4. Risk

- **Phase-3 reservation accidentally becomes Phase-3 implementation** — Mitigation: the protocol stub is **only** `Phase5EdgeBridge.noop` returning `nil`. Any PR adding real logic here is rejected; reviewers must reject PRs that cross the boundary.
- **Phase-5 refactor changes Phase-3 surface** — Mitigation: this spec is the Phase-3 contribution; any Phase-3 surface change for Phase-5 wiring requires an ADR.
- **Documentation drift between Phase-3 stub and Phase-5 implementation** — Mitigation: `api/world-integration-hook.md` is co-authored by both Phase owners; Phase 5 inherits the doc and adds implementation notes.
- **Reviewer treats the stub as done** — Mitigation: explicit `Status: Draft` + `Out of Scope` section above + cross-reference in `Phase-3/overview.md` §4.
- **Phase 4 inadvertently consumes the stub** — Mitigation: Phase 4 spec-002 IK has no business reading `Phase5EdgeBridge`; lint-like unit test asserts no `import DPIntegrationHooks` from `Phase-4` code (in fact: Phase 4 is not yet written; flag in Phase-4 review).

---

## 5. Acceptance (D-013 — 4 categories)

This spec is unusual: it MUST add **zero behavior**. Acceptance is therefore about *guarantees that no behavior ships today*.

### Performance metric

- **Compile-only**: at Phase-3 closure, `ColliderDescriptor(layer: .edge)` and `Phase5EdgeBridge.noop` MUST NOT cost any runtime CPU when the Phase-5 bridge is unset.
  - Tests assert: after `registerPhase5Bridge(nil)` and 60 simulated frames, **zero** `phase5.bridge.call` `Counter` events are emitted.
- Memory delta of `Phase5EdgeBridge.noop` ≤ 64 bytes (one static struct holding closure pointers).

### Enumerable use case

- Construct 100 `ColliderDescriptor(layer: .edge)` instances, then discard — Phase-3 world reports zero body/handle churn.
- Register `Phase5EdgeBridge.noop`, run 60 frames, register `nil`, run 60 frames — both intervals emit zero `phase5.bridge.call`.

### Assertable state

- `ColliderDescriptor(layer: .edge)` value-type compiles (signature exists).
- `Phase5EdgeBridge.noop` exists and is a static `static let` on the protocol — assertable in tests.
- `PhysicsWorld.step(dt:)` body contains the literal comment `// Phase-5 hookup point:` (regex-flagged test asserts presence).

### Previous-Phase regression

- Phase 1 + Phase 2 + `spec-001..spec-003` Acceptance still pass.
- **Memory ceiling**: cumulative Phase 3 ≤ 4 MB delta on top of Phase 2 baseline (132 MB worst-case) — this spec adds ≤ 64 bytes, well below ceiling.
- Profiler `.everyFrame` overhead unchanged from `spec-001..spec-003` baseline.
