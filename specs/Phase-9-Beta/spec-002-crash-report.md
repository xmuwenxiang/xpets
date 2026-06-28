<!--
Status: Draft
Phase: 9 — Beta (Reliability must-ship)
-->


# SPEC-002 — Crash Report (Opt-in Collection)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.

---

## 1. Goal

Crash reports with stack traces captured and uploaded to a backend. User confirms the upload opt-in.

---

## 2. Deliverables

- `DPBeta.CrashReport`:
  - On unhandled exception or signal, capture stack + thread state.
  - Apply Phase-6 Privacy Spec redaction on captured paths.
  - Buffer locally; upload on next launch + network.
- Opt-in toggle: `config.crashReporting.enabled = false` default.
- Tests:
  - Unit: injected crash → captured report contains stack trace + zero `.sensitive` payload.
  - Unit: opt-out → no upload attempt.

---

## 3. Out of Scope

- ❌ Crash backend operations — infra.

---

## 4. Risk

- **PII leaks** — Mitigation: redaction step before buffer.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- Injected crash surfaces in CI dashboard ≤ 60 s of upload (ingestion latency).
- Upload ≤ 1 MB / report.
- Memory delta ≤ 1 MB.

### Enumerable

- Injected crash → report captured.
- Opt-out → no upload.

### Assertable

- Redaction is mandatory; test asserts no `.sensitive` content in payload.

### Regression

- Phase 1..8 Acceptance still pass.
