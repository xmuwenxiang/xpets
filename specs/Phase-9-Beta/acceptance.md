# Phase 9 — Acceptance

> Phase-9 closure Acceptance in 4-category form per D-013.

---

## A. By Work Spec

### A.1 SPEC-001 Auto Update (Reliability must-ship)

| Category | Item |
|---|---|
| Performance | Manifest check ≤ 200 ms; download ≤ 1 Mbps |
| Performance | Disconnected → graceful failure + event log |
| Enumerable | Stub release server: signature verified |
| Enumerable | Network off → no install, event fired |
| Assertable | Public key `static let` |
| Regression | Phase 1..8 Acceptance still pass |

### A.2 SPEC-002 Crash Report (Reliability must-ship)

| Category | Item |
|---|---|
| Performance | Ingest latency ≤ 60 s of upload |
| Performance | Upload ≤ 1 MB / report |
| Performance | Memory delta ≤ 1 MB |
| Enumerable | Injected crash → captured report |
| Enumerable | Opt-out → no upload |
| Assertable | Redaction mandatory |
| Regression | Phase 1..8 Acceptance still pass |

### A.3 SPEC-003 Telemetry (Reliability must-ship)

| Category | Item |
|---|---|
| Performance | Privacy Mode: 24 h soak → 0 events |
| Performance | Opt-in events flushed every 30 s; memory delta ≤ 1 MB |
| Enumerable | Opt-in / opt-out toggle changes behavior |
| Enumerable | Privacy Mode → zero events |
| Assertable | Privacy filter mandatory static check |
| Regression | Phase 1..8 Acceptance still pass; Phase-6 Privacy Spec respected |

### A.4 SPEC-004 Plugin SDK (Ecosystem may-defer)

| Category | Item |
|---|---|
| Performance | Plugin load ≤ 200 ms / plugin |
| Performance | Plugin invocation overhead ≤ 0.5 ms / call |
| Enumerable | 3 stub plugins registered |
| Enumerable | Plugin Skill invokes succeed |
| Assertable | Unsigned plugin rejected |
| Assertable | Default-deny Privacy enforced |
| Regression | Phase 1..8 Acceptance still pass |

### A.5 SPEC-005 Skill Marketplace (Ecosystem may-defer)

| Category | Item |
|---|---|
| Performance | Install → uninstall ≤ 5 s / skill |
| Performance | Memory delta ≤ 1 MB |
| Enumerable | 3 listings visible; unsigned rejected |
| Enumerable | Install → launch → Skill listed |
| Assertable | Signature verification mandatory |
| Assertable | Version-pin honored |
| Regression | Phase 1..8 Acceptance still pass; Phase-7 unchanged |

---

## B. Phase-9 Cumulative Row

| Category | Item |
|---|---|
| Performance | Reliability subset total runtime memory ≤ **104 MB** (Phase 8 100 + 4) |
| Performance | Ecosystem subset total ≤ **110 MB** (if shipped) |
| Performance | Installer ≤ 30 MB |
| Enumerable | Auto Update completes an end-to-end stub-server flow |
| Enumerable | Crash injected, surfaced in CI dashboard ≤ 60 s |
| Enumerable | Privacy Mode emits zero events over 24 h soak |
| Assertable | Phase-6 Privacy Spec boundary enforced across all channels |
| Assertable | D-011 — Reliability subset shipped; Ecosystem subset decision recorded |
| Regression | All Phase 1..8 `acceptance.md` items pass at end of Phase 9 |

---

## C. D-011 Deferral Decision

At Phase-9 closure, this decision must be explicit:

| Subset | Ship Status | ADR Required? |
|---|---|---|
| SPEC-001 Auto Update | **Must ship** | No (mandatory) |
| SPEC-002 Crash Report | **Must ship** | No (mandatory) |
| SPEC-003 Telemetry | **Must ship** | No (mandatory) |
| SPEC-004 Plugin SDK | **Open**: ship or defer to v1.1 | Yes if deferred |
| SPEC-005 Skill Marketplace | **Open**: ship or defer to v1.1 | Yes if deferred |

If ecosystem defers, a `D-NNN-ecosystem-deferral` ADR is created with the rationale.

---

## D. Ship Hardening Final Cross-Check

- Phase 8 Hardening rolled forward into Phase-9 → all Phase-1..8 budget rows remain green.
- Installer signed + notarized (per Phase-8 spec-006).
- Privacy Spec (Phase-6) cross-checks in all 5 specs above (default-deny + redaction + opt-in).
