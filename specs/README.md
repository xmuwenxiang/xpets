# Specs (Phase-Based, v2)

> Authoritative specification index for the AI Native 3D Desktop Pet.
> Authored under `00-spec-conventions.md` (Apple Spec style + 4-category Acceptance per D-013).
> **Last updated**: 2026-06-28.

---

## 1. Top-Level Documents

| Doc | Purpose |
|---|---|
| [`00-spec-conventions.md`](00-spec-conventions.md) | Spec-writing rules: Apple style template, status tags, traceability, forbidden practices |
| [`_legacy/specs-v1-44-spec-DEPRECATED.md`](_legacy/specs-v1-44-spec-DEPRECATED.md) | Legacy 44-Spec module decomposition (preserved for traceability only — never authoritative, **DEPRECATED**) |
| [`_legacy/migration-map.md`](_legacy/migration-map.md) | Legacy-SPEC → v2-Phase destination mapping |

For roadmap, decisions, and architecture, see the cross-repo roots:

- **Roadmap** (Phase ordering, D-001..D-013): [`../roadmap.md`](../roadmap.md)
- **Decisions** (ADRs): [`../decisions/README.md`](../decisions/README.md)
- **Architecture**: [`../architecture/README.md`](../architecture/README.md)
- **API documentation**: [`../api/`](../api/)

---

## 2. Phase Status

| # | Phase | Status | Overview | Closure Proof |
|---|---|---|---|---|
| 1 | Foundation | **Done (2026-06-28)** | [`Phase-1-Foundation/overview.md`](Phase-1-Foundation/overview.md) | [acceptance.md](Phase-1-Foundation/acceptance.md) + [checklist.md](Phase-1-Foundation/checklist.md) — committed `d4d974b`, CI green `168efa6` |
| 2 | Rendering | 5 Work Specs **Draft** (2026-06-28) | [`Phase-2-Rendering/overview.md`](Phase-2-Rendering/overview.md) | Apple-Style + 4-category Acceptance drafted for spec-001..spec-005. Implementation gated on owner review + `Status: Approved` per `00-spec-conventions.md` §7. Cumulative Phase-2 memory budget target ≤ 128 MB worst-case (frozen for Phase-3/4/5 regression baselines). |
| 3 | Physics | Stub | [`Phase-3-Physics/overview.md`](Phase-3-Physics/overview.md) | Same as Phase 2. Must carry **World Integration Reservation** (Collider-Edge) per D-003. |
| 4 | Animation | Stub | [`Phase-4-Animation/overview.md`](Phase-4-Animation/overview.md) | Same. Must carry **World Integration Reservation** (Animation-Driver *signature only*; implementation cross-delivered by Phase 5 per D-007). IK scope fixed by D-012: Two-Bone / CCD / Foot / Look-At. |
| 5 | DesktopWorld (5a + 5b) | Stub | [`Phase-5-DesktopWorld/overview.md`](Phase-5-DesktopWorld/overview.md) | Phase 5 internally splits (D-005). Owns the *real* implementation of the Animation-Driver hook reserved in Phase 4 (D-007). |
| 6 | Behavior | Stub | [`Phase-6-Behavior/overview.md`](Phase-6-Behavior/overview.md) | Local Behavior Runtime only — no LLM dependency. Skill concept stubbed here, real runtime in Phase 7 (D-006). Privacy boundary declared here. |
| 7 | AI | Stub | [`Phase-7-AI/overview.md`](Phase-7-AI/overview.md) | Claude CLI + tool calling + Skill runtime + Failure Mode Matrix (≥ 5 scenarios). |
| 8 | Hardening | Stub | [`Phase-8-Hardening/overview.md`](Phase-8-Hardening/overview.md) | Whole-system CPU / GPU / battery / memory / installer pass (D-009). Targets: < 100 MB runtime, < 30 MB installer. |
| 9 | Beta | Stub | [`Phase-9-Beta/overview.md`](Phase-9-Beta/overview.md) | Reliability (must-ship: Auto Update, Crash Report, Telemetry) + Ecosystem (may-defer to v1.1: Plugin, Skill Marketplace). |

### 2.1 Status Legend

- **Done** — All Work Specs `Status: Done`; checklist fully checked; CI green on the Phase closure commit; frozen for downstream regression.
- **5 Work Specs Draft** — All planned deliverables have Apple-Style + 4-category Acceptance written; status tags in `[Draft, Draft, Draft, Draft, Draft]`; none has entered `In Review`. Implementation gated on owner review and `Status: Approved`.
- **Stub** — `overview.md` is a *placeholder* with risk + pre-known deliverables sketched, but Work Spec files do not yet exist. Content authoring begins when the previous Phase closes.

> Per `00-spec-conventions.md` §10, Phase directories must never be deleted; Done phases are **frozen** except for typo fixes via ADR.

---

## 3. How to Read a Phase File

For any `Phase-N-<Name>/overview.md`:

1. **Goal** — what ships at Phase close (user-visible).
2. **Pre-known Deliverables** — Work Specs to be authored when Phase starts.
3. **Out of Scope** — capabilities reserved for later Phases (anti-scope-creep guard).
4. **World Integration Reservation** — ONLY for Phase 3 / Phase 4 (D-003).
5. **Risk** — failure modes + cross-Phase risks.
6. **Acceptance** — in 4-category form (Performance / Enumerable / Assertable / Previous-Phase regression) per D-013.
7. **Cross-References** — back-pointers to ADRs and dependent Work Specs.

When Phase 2+ authoring begins, the PLACEHOLDER Acceptance prose is rewritten into the 4-category form, and the Status transitions `Stub → Draft → In Review → Approved → Implementing → Done`.

---

## 4. Phase-1 Closure Snapshot (frozen baseline)

For budget regression baselines used by Phase 2+ Acceptance, see:

- [`Phase-1-Foundation/acceptance.md`](Phase-1-Foundation/acceptance.md) — 31-row Acceptance table (Performance / Enumerable / Assertable / Previous-Phase).
- [`Phase-1-Foundation/checklist.md`](Phase-1-Foundation/checklist.md) — Sign-off checklist with three explicit unblock items (Phase 2 owner confirms readiness, Project owner sign-off, Git tag `phase-1-foundation`).

> **Memory reconciliation baseline** (frozen for Phase 2+ regression):
> spec-003 Runtime cold-start ≤ 30 MB + spec-004 Asset cache upper-bound ≤ 32 MB + spec-002 Window ≤ 1 MB + spec-005 Animation buffers ≤ 2 MB → **≤ 65 MB worst-case**.
