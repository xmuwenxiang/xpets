<!--
Status: Draft
Phase: 9 — Beta (Ecosystem may-defer per D-011)
-->


# SPEC-004 — Plugin SDK Contract (Ecosystem)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> **May slip to v1.1 per D-011.**

---

## 1. Goal

Define a Swift-binary plugin contract (`DPBeta.Plugin`) that allows third-party extensions. Plugins are sandboxed; can provide Skills, Events, and read-only Phase-5 Desktop introspection.

---

## 2. Deliverables

- `DPBeta.Plugin` protocol:
  - `func load() async throws` lifecycle.
  - `func skills() -> [Skill]` returns Skills.
  - `func events() -> AsyncStream<PluginEvent>`.
- PluginManager:
  - Registers plugins via sandboxed `/Library/Application Support/PetPlugins/<plugin-id>` paths.
  - Per-plugin permission: defaults to Phase-6 Privacy Spec default-deny.
  - Plugin bundles must be code-signed.

---

## 3. Out of Scope (Phase 9)

- ❌ Marketplace integration — `spec-005-skill-marketplace.md`.

---

## 4. Risk

- **Plugin escape** — Mitigation: Swift module sandbox + macOS sandbox profile.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- Plugin load ≤ 200 ms / plugin.
- Plugin invocation overhead ≤ 0.5 ms / call.

### Enumerable

- 3 stub plugins registered.
- Plugin Skill invokes → succeeds.
- Plugin event stream emits one event per plugin.

### Assertable

- Plugins must be code-signed; unsigned plugin rejected.
- Privacy default-deny enforced.

### Regression

- Phase 1..8 Acceptance still pass.

> Note: D-011 allows Phase-9 Beta release without this spec shipping. If deferred, a `D-NNN-ecosystem-deferral` ADR is required.
