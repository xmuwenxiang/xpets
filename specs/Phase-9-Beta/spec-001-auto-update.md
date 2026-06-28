<!--
Status: Draft
Phase: 9 — Beta (Reliability must-ship per D-011)
-->


# SPEC-001 — Auto Update (Binary + Assets)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.

---

## 1. Goal

Background-check for updates every 6 hours. On detection, download + verify + auto-install at next launch. Failures degrade gracefully.

---

## 2. Deliverables

- `DPBeta.AutoUpdate`:
  - Manifest check against `https://releases.desktop-pet.app/manifest.json` over HTTPS.
  - Signature verification via Ed25519 public key baked into the app.
  - Download → verify → atomic-installer-install on next launch.
- Failure modes (per Phase-7 Failure Mode matrix template; added in spec-009):
  - Network down → defer to next 6-hour tick.
  - Manifest signature fails → fail-closed; AlertOnce.
  - Disk space < 200 MB → fail-closed; AlertOnce.
- Tests:
  - Unit: manifest fetch → signature verify path.
  - Unit: network-off simulator → Auto Update does NOT progress; emits `AutoUpdateEvent.failed(reason: .networkOffline)`.
  - End-to-end: stub release server returns a manifest with a known update.

---

## 3. Out of Scope

- ❌ CDN furnishing — Phase 9+ infra.
- ❌ Telemetry install counts — falls under spec-003.

---

## 4. Risk

- **`/usr/bin/install` sandbox denial** — Mitigation: Phase-8 installer signed and notarized; macOS Gatekeeper accepts.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- Manifest check ≤ 200 ms.
- Download time ≤ 1 Mbps (typical).
- Disconnected-network → graceful-failure state + `AutoUpdateEvent.failed(reason:)` log.

### Enumerable

- Stub release server: manifest fetched, signature verified.
- Network off → no install progress, event fired.

### Assertable

- Public key `static let`.
- Event log adheres to Failure Mode schema.

### Regression

- Phase 1..8 Acceptance still pass.
