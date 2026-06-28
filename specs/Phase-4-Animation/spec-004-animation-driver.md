<!--
Status: Draft
Phase: 4 — Animation
Owner: TBD
Depends: Phase 1 spec-005-animation.md
ADRs:   D-003 (mandatory reservation), D-007 (Phase-5 cross-delivers implementation), D-013
-->

# SPEC-004 — AnimationDriver (Signature Reservation, D-007)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> **This spec exists because D-003 + D-007 make a Phase-4 reservation mandatory.** Phase 4 ships the *signature* of the AnimationDriver protocol and **zero** concrete implementations. Phase 5 fills the body per D-007.

---

## 1. Goal

Document and expose (in Phase 4) the public `AnimationDriver` protocol whose method body is **cross-delivered by Phase 5**. Phase 4 ships:
- the protocol declaration,
- a `Phase4AnimationDriver.noop` static struct that returns zero-offset on every call (used by Phase 4 tests as the doc-cited default),
- a `phase4_animation_driver_signature_compiles` test asserting the protocol compiles.

After SPEC-004 ships, Phase 5 substitute the no-op with a real implementation (cursor tracking, Dock interaction, puppeteering body parts) **without** changing Phase-4 public API.

---

## 2. Deliverables

- **`DPAnimation.AnimationDriver` protocol** — declared in Phase 4:
  ```swift
  public protocol AnimationDriver: AnyObject {
      func apply(offset: SIMD3<Float>, to: Bone.ID)
      func reset(to: Bone.ID)
  }
  ```
- **`DPAnimation.Phase4AnimationDriver`** — static struct with `.noop` constant whose methods are documented but **must not be called by Phase 4 source tree**. The `apply(offset:to:)` and `reset(to:)` methods exist only to satisfy protocol conformance; Phase 4 exercises neither path in production.
- **Phase-4-source invariant** — no concrete class in Phase-4 module conforms to `AnimationDriver`. Tests assert via Swift runtime reflection:
  - `allConformingTypes(in: DPAnimation.self, to: AnimationDriver.self)` returns `[]` (zero concrete types from Phase-4).
  - The `Phase4AnimationDriver.noop` constant is *technically* a struct but not registered as a conformance (it lives in a separate `Phase4AnimationDriver` namespace, not directly implementing `AnimationDriver`).
- Tests:
  - Compile: `AnimationDriver` protocol compiles; referencable from outside Phase-4 module.
  - Unit: `Phase4AnimationDriver.noop` exists. Calling `.noop.apply(offset:to:)` is a no-op (`Bone.ID` parameter receives invalid `0` in test, no crash).
  - Unit: reflection test asserts zero Phase-4-owned concrete types conform to `AnimationDriver`.
- **API docs**: `api/animation-driver-hook.md` — explicitly marked **Phase-5-facing public** with the message "Phase-4 ships signature only; Phase-5 implements, see Phase-5a/.../spec-NNN-render-route.md".

---

## 3. Out of Scope

- ❌ **Real AnimationDriver implementation** — Phase 5 (cross-delivered per D-007).
- ❌ Cursor integration — Phase 5a.
- ❌ Dock-edge interaction dispatch — Phase 5b.
- ❌ Gesture or touch handling — Phase 5b/9.
- ❌ Network-driven AnimationDriver (remote puppeting) — out.

---

## 4. Risk

- **Phase-4 accidentally ships a concrete implementation** — Mitigation:
  1. The reflection test asserts zero conforming types in Phase-4 module.
  2. Reviewers must reject any PR adding an `AnimationDriver` conformer to Phase-4 source tree.
  3. CI gate: a custom swift-syntax macro count asserts ≥ 0 `extension AnimationDriver` in Phase-4 directory.
- **Phase-5 refactor changes Phase-4 public API** — Mitigation: `api/animation-driver-hook.md` declares the signature frozen; any signature change requires an ADR.
- **Documentation drift between Phase-4 stub and Phase-5 implementation** — Mitigation: `api/animation-driver-hook.md` is co-authored by Phase-4 + Phase-5 owners; Phase-5 inherits and adds implementation notes.
- **Phase-4 readers/consumers confused about ownership** — Mitigation: explicit `// NOTE: body is filled by Phase 5 per D-007` annotation on every `AnimationDriver` reference in Phase-4 source.
- **Reflection test platform-leakage on Swift versions** — Mitigation: reflection is via `String(reflecting:)` and module-name string. Test asserts module names are stable.

---

## 5. Acceptance (D-013 — 4 categories)

This spec is unusual: it MUST add **zero behavior** (similar to Phase-3 `spec-004-world-reservation.md`). Acceptance is about guarantees that no behavior ships today.

### Performance metric

- `AnimationDriver.apply(offset:to:)` is **never called** in Phase 4 by any production path. Tests assert: a 600-frame integration run with `Phase4AnimationDriver.noop` instantiated emits **zero** `animation.driver.call` `Counter` events.
- Memory delta of `Phase4AnimationDriver.noop` constant ≤ 64 bytes (alignment-free struct).

### Enumerable use case

- Construct `Phase4AnimationDriver.noop`, call `.apply(offset:.zero, to: 0)` × 1000 — zero observable effect, zero counter events, zero bone matrix mutations (compared against a pose snapshot).
- Reflection test asserts no Phase-4-owned concrete AnimationDriver implementation exists.

### Assertable state

- `AnimationDriver` protocol declaration exists; comments annotate it is "Phase-5-cross-delivered per D-007".
- `allConformingTypes(in: DPAnimation.self, to: AnimationDriver.self)` is empty — assertable.
- `Phase4AnimationDriver.noop` is a `static let` — assertable.

### Previous-Phase regression

- Phase 1 + Phase 2 + Phase 3 + Phase-4 `spec-001..003` Acceptance still pass.
- Memory ceiling: cumulative Phase 4 ≤ 6 MB delta on top of Phase-3 baseline (≤ 142 MB worst-case). This spec adds ≤ 64 bytes.
- Profiler `.everyFrame` overhead unchanged from Phase-3 baseline.
