<!--
Status: Draft
Phase: 9 — Beta (Ecosystem may-defer per D-011)
-->


# SPEC-005 — Skill Marketplace (Ecosystem)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> **May slip to v1.1 per D-011.**

---

## 1. Goal

A marketplace UI + backend contract where users can install third-party Skills.

---

## 2. Deliverables

- `DPBeta.SkillMarketplace`:
  - Listings: `{ id, name, version, description, author, signedBy }`.
  - `install(id:version:) async throws` — downloads + verifies + stage for next-launch.
  - Sandboxed install path `/Library/Application Support/PetPlugins/<plugin-id>`.
- Version-pinning policy: Skills declare `version`; Phase-7 Skill Runtime uses exact match by default.
- Tests:
  - Unit: install → uninstall cycle ≤ 5 s per skill.
  - Unit: signed install succeeds.
  - Unit: unsigned install rejected with `MarketplaceError.signatureInvalid`.

---

## 3. Out of Scope (Phase 9)

- ❌ Marketplace backend operations — infra.

---

## 4. Risk

- **Sandbox breach** — Mitigation: per-plugin entitlements; same as spec-004.
- **Skill version drift** — Mitigation: Phase-9 ships version-pin policy.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- Install → uninstall ≤ 5 s per skill.
- Memory delta ≤ 1 MB.

### Enumerable

- 3 listings visible; one unsigned rejected.
- Install → launch → Skill listed in registry.

### Assertable

- Signature verification mandatory.
- Version-pin policy honored.

### Regression

- Phase 1..8 Acceptance still pass; Phase-7 Skill Runtime behavior unchanged.

> Note: D-011 allows Phase-9 Beta release without this spec shipping. If deferred, a `D-NNN-ecosystem-deferral` ADR is required.
