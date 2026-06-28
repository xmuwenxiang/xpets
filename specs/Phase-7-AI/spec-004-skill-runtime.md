<!--
Status: Draft
Phase: 7 — AI
Owner: TBD
Depends: Phase 6 Behavior (Skill stub per D-006)
ADRs:   D-006 (Phase-7 owns full Skill runtime; Phase-6 stub), D-008, D-013
-->

# SPEC-004 — Skill Runtime (Registry, Permissions, Lifecycle)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> Phase-7 cross-deliverable per **D-006**. Phase 6 ships Skill as a data type; Phase 7 wires registration, permission checks, lifecycle hooks.

---

## 1. Goal

Bring up the Skill runtime that turns a typed `Skill` definition into a callable, permission-gated, lifecycle-managed function. After SPEC-004 ships, an Intent case like `.speak` resolves to a Skill that has been registered with a permission grant, runs in the correct lifecycle phase, and emits a typed result.

---

## 2. Deliverables

- `DPBehavior.Skill` (Phase 6 type) is now a fully-functional runtime protocol:
  ```swift
  protocol Skill {
      var name: String { get }
      var version: String { get }    // Phase-9 Marketplace compat
      var requiredPermissions: Set<SkillPermission> { get }
      func invoke(_ args: SkillArguments, context: SkillContext) async throws -> SkillResult
  }
  ```
- `DPBehavior.SkillRegistry`:
  - `register(_ skill: Skill)` — appends to a named list keyed by `name + version`.
  - `lookup(name:version:)` — returns `Skill?` or throws `SkillError.notFound`.
  - `permissions(grantedTo skill:)` — user-prompt-driven; stored across launches in `DPFoundation.Config`.
- `DPBehavior.SkillPermission` enum (precise set):
  - `move`, `speak`, `readScreen` (Phase-6 Privacy visibility-class gated), `openApp`, `lookAt`, `playAnimation`, `playSound`.
- Lifecycle phases:
  - `preInvoke` → permission check.
  - `invoke` → action.
  - `postInvoke` → telemetry / undo stack.
  - `cleanup` → revoke transient resources.
- Tests:
  - Unit: register a `SpeakSkill` with `requiredPermissions = [.speak]`, invoke with permission granted → success.
  - Unit: same invoke with permission denied → throws `SkillError.permissionDenied`.
  - Unit: lifecycle ordering — probe observability asserts `preInvoke → invoke → postInvoke → cleanup` order.
  - Unit: `Skill.version` is mandatory; registry refuses nameless versions.
- **API docs**: `api/skill-runtime-api.md` — registry, permission grant flow, lifecycle hooks.

---

## 3. Out of Scope

- ❌ Built-in Skills themselves — `spec-005-built-in-skills.md`.
- ❌ MCP tool bridge for Skills — `spec-006-mcp-bridge.md`.
- ❌ Skill marketplace / install — Phase 9.

---

## 4. Risk

- **Permission grant UX** — first-use should prompt; tests assert prompt fires only once per skill per launch.
- **Skill hot-reload during invoke** — Mitigation: registry snapshot during invoke; reload only between `preInvoke`s.
- **Cross-skill state contamination** (SpeakSkill referencing Move's frame state) — Mitigation: Skills declare `SkillArguments` with `Sendable` types only.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- Skill registration overhead ≤ 50 µs / skill.
- Skill invocation overhead ≤ 0.5 ms P99 (excluding the Skill's actual work).
- Memory delta ≤ 1 MB on top of Phase-6 baseline.
- Profiler budget unchanged.

### Enumerable use case

- 5 Skills registered, registered-count assertion.
- SpeakSkill invoked with permission granted → success.
- SpeakSkill invoked with permission denied → throws.
- Lifecycle assertion: probe observability records all four phases.

### Assertable state

- `SkillRegistry` is `Sendable`-safe.
- `Skill.requiredPermissions` is statically declared, no permission can be added at runtime.
- Failure Mode entries (`SkillError.permissionDenied`, `.notFound`, `.invalidArgs`) are exhaustive.

### Previous-Phase regression

- Phase 1..6 Acceptance still pass.
- Phase-6 Skill stub continues to compile (now as a protocol, not a struct).
