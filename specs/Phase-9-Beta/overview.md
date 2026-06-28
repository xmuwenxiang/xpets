# Phase 9 — Beta

> **Status**: Stub — Phase 8 closure gating begins content authoring.
> **Goal**: Ship the product. Auto Update + Crash Report + Telemetry form the reliability floor. Plugin + Skill Marketplace form the ecosystem layer.
> **Internal split (D-011)**: reliability subset is mandatory for ship; ecosystem subset may slip to v1.1.

> ⚠️ **PLACEHOLDER — content authoring begins when Phase 8 closes.** Acceptance prose below is rewritten in 4-category form (D-013) at Phase 9 start.

---

## Goal (Phase 9 final)

A signed, notarized, auto-updating Desktop Pet that runs on Apple Silicon Macs. Third-party Skill Marketplace exists. Crash reports flow back. Telemetry collection is opt-in.

---

## Pre-known Deliverables (to be expanded)

### Reliability (must-ship)
- `spec-001-auto-update.md` — Auto Update of binary + assets
- `spec-002-crash-report.md` — Crash collection / user-confirmed upload
- `spec-003-telemetry.md` — Opt-in telemetry (FPS, Memory, Crash Counters, Skill Usage, AI Usage)

### Ecosystem (may-defer to v1.1)
- `spec-004-plugin.md` — Plugin SDK contract
- `spec-005-skill-marketplace.md` — Skill Marketplace listing / install / version

---

## Out of Scope (Phase 9)

- ❌ Vision Pro / AR port — post-Phase 9 roadmap
- ❌ Multi-Pet cohabitation — post-Phase 9 roadmap
- ❌ Polymorphic AI / Multi-Agent — post-Phase 9 roadmap

---

## Risk (placeholder)

- Auto Update failure leaving user on stale version
- Crash report containing sensitive paths
- Marketplace Skill sandbox breach
- Telemetry related to GDPR / CCPA

---

## Acceptance (placeholder — 4-category form per D-013)

- Auto Update: disconnected-network test path returns graceful-failure state and logs an `AutoUpdateEvent.failed(reason:)` event (Assertable)
- Crash Report: injected crash surfaces in CI dashboard within ≤ 60 s of upload (Performance metric — ingestion latency)
- Marketplace: install → uninstall cycle completes ≤ 5 s per Skill (Performance metric)
- Privacy mode: emits zero `TelemetryEvent` payloads over 24 h soak (Assertable — event count == 0)

> All four are placeholder lines. The full Phase 9 Acceptance block, in 4-category form, is rewritten when Phase 9 content authoring begins.

---

## Cross-References

- Phase 6 Privacy Spec applies here (telemetry must respect)
- Phase 7 Failure Mode Matrix — Auto Update failure is a new mode to add
- Phase 8 Installer/Signing foundation
