<!--
Status: Draft
Phase: 9 — Beta (Reliability must-ship)
-->


# SPEC-003 — Telemetry (Opt-in, Privacy-respecting)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.

---

## 1. Goal

Opt-in telemetry: FPS, Memory, Crash Counters, Skill Usage, AI Usage. Privacy-respecting — never includes `.sensitive` payloads.

---

## 2. Deliverables

- `DPBeta.Telemetry`:
  - Sampling policy: 1 event / minute aggregate; daily rollups.
  - Opt-in: `config.telemetry.enabled = false` default.
  - Privacy redaction: per Phase-6 Boundary Guard.
- Tests:
  - Unit: opt-out → zero events emitted.
  - Unit: opt-in → events emitted with redaction.
- Privacy Mode test: emits zero `TelemetryEvent` payloads over 24 h soak (assertable event count == 0).

---

## 3. Out of Scope

- ❌ Backend operations — infra.

---

## 4. Risk

- **GDPR / CCPA compliance** — Mitigation: opt-in default-on; one-click opt-out across `Settings`.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- Privacy Mode: 24 h soak → 0 events.
- Opt-in: events flushed every 30 s; memory delta ≤ 1 MB.

### Enumerable

- Opt-in / opt-out toggle changes behavior immediately.
- Privacy Mode spec-output: zero events.

### Assertable

- Privacy filter is mandatory static check.

### Regression

- Phase 1..8 Acceptance still pass; Phase-6 Privacy Spec respected.
