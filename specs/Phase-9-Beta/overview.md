<!--
Status: Drafts authored (2026-06-28)
Phase: 9 — Beta
Owner: TBD
ADRs:  D-011 (Reliability must-ship, Ecosystem may-defer), D-013
-->

# Phase 9 — Beta

> **Status**: Stub → **Drafts authored (2026-06-28)**. Five Work Specs now exist at Apple Style + 4-category Acceptance. **Reliability subset is must-ship per D-011**; **Ecosystem subset may slip to v1.1** if a specific deliverable's Acceptance cannot be met at Beta cutoff.
> **Goal**: Ship the product. Auto Update + Crash Report + Telemetry form the reliability floor. Plugin + Skill Marketplace form the ecosystem layer.

---

## 1. Goal (Phase 9 final)

A signed, notarized, auto-updating Desktop Pet that runs on Apple Silicon Macs. Third-party Skill Marketplace exists. Crash reports flow back. Telemetry collection is opt-in.

After Phase 9 closes, a user can:
- launch the .app and run indefinitely,
- auto-receive patch updates,
- opt-in to crash reporting,
- install third-party Skills via the Marketplace (subject to D-011 deferral).

---

## 2. Pre-known Deliverables (finalized)

### Reliability (must-ship)

- [`spec-001-auto-update.md`](spec-001-auto-update.md) — Auto Update of binary + assets.
- [`spec-002-crash-report.md`](spec-002-crash-report.md) — Crash collection / user-confirmed upload.
- [`spec-003-telemetry.md`](spec-003-telemetry.md) — Opt-in telemetry (FPS, Memory, Crash Counters, Skill Usage, AI Usage).

### Ecosystem (may-defer to v1.1)

- [`spec-004-plugin.md`](spec-004-plugin.md) — Plugin SDK contract.
- [`spec-005-skill-marketplace.md`](spec-005-skill-marketplace.md) — Skill Marketplace listing / install / version.

---

## 3. Internal Split (D-011 — Reliability / Ecosystem)

Per **D-011**:
- **Reliability subset** (spec-001..spec-003) is **must-ship**. Auto Update, Crash Report, Telemetry are non-negotiable for Beta.
- **Ecosystem subset** (spec-004..spec-005) **may slip** to v1.1 if the deadline cannot meet Acceptance. The decision is made at Phase-9 closure review; an ADR is required if either ecosystem spec defers.

---

## 4. Out of Scope (Phase 9)

- ❌ Vision Pro / AR port — post-Phase-9 roadmap.
- ❌ Multi-Pet cohabitation — post-Phase-9 roadmap.
- ❌ Polymorphic AI / Multi-Agent — post-Phase-9 roadmap.

---

## 5. Risk (placeholder)

- **Auto Update failure leaving user on stale version** — Mitigation: spec-001 covers graceful-failure paths.
- **Crash report containing sensitive paths** — Mitigation: spec-002 applies Phase-6 Privacy Spec redaction.
- **Marketplace Skill sandbox breach** — Mitigation: spec-004 + spec-005 follow macOS sandbox defaults + Phase-6 Privacy boundary.
- **Telemetry related to GDPR / CCPA** — Mitigation: spec-003 is **opt-in** and excludes `.sensitive` payloads.

---

## 6. Acceptance (placeholder — 4-category form finalized in `acceptance.md`)

See [`acceptance.md`](acceptance.md).

Reliability cumulative delta: ≤ 4 MB on top of Phase-8 baseline; **must converge** at 100 MB total runtime.
Ecosystem cumulative delta: ≤ 6 MB if shipped; may be deferred.

---

## 7. Cross-References

- **Phase 6**: `spec-006-privacy-behaviour-boundaries.md` (Telemetry + Marketplace must respect Privacy Spec).
- **Phase 7**: `spec-008-failure-mode-matrix.md` (Crash report format mirrors Failure Mode events).
- **Phase 8**: `spec-006-installer-pipeline.md` (Auto Update reuses signing pipeline).
- **ADRs**: D-011, D-013.
