<!--
Status: Draft
Phase: 6 — Behavior
ADRs:   D-006 (mandatory privacy boundaries)
-->



# SPEC-006 — Privacy & Behavior Boundaries (Mandatory)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> **Mandatory Privacy sub-Spec.** Defines the contract and the Boundary Guard that enforces it.

---

## 1. Goal

Establish the privacy contract:
- entities with `.sensitive` are never exposed to Intent, IPC, Chat, or Telemetry;
- `read_screen` / OCR / clipboard reads are default-denied;
- user actions are irreversible and explicit.

After SPEC-006 ships, the Boundary Guard is a Runtime module that wraps every Phase-7 Skill invoke and rejects boundary violations.

---

## 2. Deliverables

- `DPBehavior.PrivacySpec` (the spec-as-code manifest):
  - Default-deny list: `read_screen`, `ocr`, `clipboardRead`, `appFocusPrivate`.
  - Mapping rules: which app/bundle → which `visibilityClass`.
- `DPBehavior.BoundaryGuard` (Runtime module):
  - Wraps every Skill invocation: pre-checks the Skill's required permissions against `PrivacySpec`.
  - Rejects with `BoundaryViolationError` if denied.
  - Logs every boundary check as `privacy.guard.check` event for Telemetry.
- Mapping source: hand-curated app/bundle list; updates possible at runtime for Phase 9 Marketplace.
- Audit log stored in Memory store (`spec-004-memory.md`).
- Tests:
  - Unit: 5 default-deny operations each rejected.
  - Unit: a Skill requiring `read_screen` is refused. The Runtime catches the throw → emits the corresponding `privacy.guard.reject` event.
  - Privacy: telemetry payload for an attempted `read_screen` Skill contains zero content data.
  - Audit: every boundary check is observable in audit log.

---

## 3. Out of Scope

- ❌ Marketplace-driven policy override — Phase 9.
- ❌ OCR per se — forbidden.

---

## 4. Risk

- **Phase-7 Skill attempts to bypass** — Mitigation: Boundary Guard wraps every Skill, no Phase-7 code can opt out.
- **Mapping table drift** — Mitigation: `PrivacySpec` is `Codable` and persists; runtime override is logged.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- `BoundaryGuard.check` P99 ≤ 1 µs (cheap gate).
- Memory delta ≤ 1 MB (mapping table size).
- Profiler budget unchanged.

### Enumerable

- 5 default-deny operations → 5 rejections.
- Read-screen Skill → rejected.
- Audit log: 6 boundary events.

### Assertable

- Privacy default-deny list is `static let`.
- Boundary Guard is the *only* path to Skill.invoke (refl. assertion).

### Regression

- Phase 1..5 Acceptance still pass.
- Privacy contract is referenced by Phase-7 acceptance.md §D.
