<!--
Status: Draft
Phase: 6 — Behavior
ADRs:   D-006 (Phase-6 stub → Phase-7 real runtime)
-->



# SPEC-007 — Skill Stub (D-006 Cross-Deliverable)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> **Phase 6 ships the Skill protocol declaration only**; Phase 7 (`spec-004-skill-runtime.md`) fills the registry / lifecycle / permissions. This is the **stub half** of the D-006 cross-deliverable.

---

## 1. Goal

Document and expose (in Phase 6) the public `DPBehavior.Skill` protocol with zero concrete conformers in the Phase-6 module. Phase 7 ships conformers.

---

## 2. Deliverables

- `DPBehavior.Skill` protocol declaration:
  ```swift
  public protocol Skill: AnyObject {
      var name: String { get }
      var version: String { get }
      var requiredPermissions: Set<SkillPermission> { get }
      func invoke(_ args: SkillArguments, context: SkillContext) async throws -> SkillResult
  }
  ```
- Companion types `SkillArguments`, `SkillContext`, `SkillResult`, `SkillPermission` — all stub types only, no concrete conformers.
- **Phase-6 reflection invariant**: zero concrete types conform to `Skill` in `DPBehavior` module.
- Tests:
  - Compile: `Skill` protocol compiles; referenceable.
  - Reflection: zero Phase-6-owned concrete conformers.

---

## 3. Out of Scope

- ❌ Skill registry, lifecycle, permissions — Phase 7.
- ❌ Built-in Skills — Phase 7.

---

## 4. Risk

- **Stub accidentally conformed** — same mitigation as Phase-4 spec-004: reflection test asserts zero conformers; CI gate via SwiftPM target boundary.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- Memory delta ≤ 64 bytes (one static-namespace placeholder).
- 0 ms / frame (stub never invoked).

### Enumerable

- Stub exists; no conformers.

### Assertable

- Reflection test asserts zero `DPBehavior`-owned concrete conformers.
- `Skill` protocol declaration includes "Phase-7-fills-body per D-006" comment.

### Regression

- Phase 1..5 Acceptance still pass.
