<!--
Status: Drafts authored (2026-06-28)
Phase: 6 — Behavior
Owner: TBD
ADRs:  D-006 (Skill stub in Phase 6, real runtime in Phase 7 — D-006 cross-deliverable) + **Mandatory Privacy & Behavior Boundaries spec**, D-008, D-013
-->

# Phase 6 — Behavior

> **Status**: Stub → **Drafts authored (2026-06-28)**. Seven Work Specs now exist at Apple Style + 4-category Acceptance; implementation gated on owner review + `Status: Approved`.
> **Goal**: Make the fox feel alive. Utility AI scores behavior (Sleep / Eat / Play / Observe / Talk / Explore). Emotion regulates Energy / Curiosity / Trust / Happiness. Memory anchors state across runtime instances. Daily Routine produces a believable rhythm.
> **Mandatory add-on**: a **Privacy & Behavior Boundaries** sub-Spec — the fox is now an always-on resident on the desktop and ethical / privacy boundaries must be defined before any Decide.
> **Skill stub**: per **D-006**, the Skill concept appears here as a stub so Phase 7 has a real extension point. Phase 7 fills the body (cross-deliverable).

---

## 1. Goal (Phase 6 final)

A running fox that acts on local heuristics (no LLM). It chooses behaviors, expresses via Animation Layer (Phase 4), respects privacy boundaries, records memory, and follows a daily routine.

After Phase 6 closes, the Pet exhibits local intelligence at startup — no Claude required to feel alive. Privacy Spec is in force; the Pet has no capability to OCR user content. Skills are typed and referenceable but their implementations arrive in Phase 7.

---

## 2. Pre-known Deliverables (finalized)

- [`spec-001-behavior-fsm.md`](spec-001-behavior-fsm.md) — Baseline states (Idle, Decide, Run, Cleanup).
- [`spec-002-utility-ai.md`](spec-002-utility-ai.md) — Utility AI scoring across daily behaviors.
- [`spec-003-emotion.md`](spec-003-emotion.md) — Emotion (Energy / Curiosity / Trust / Happiness).
- [`spec-004-memory.md`](spec-004-memory.md) — Local Memory store (SQLite-backed in Phase 6; not deferred).
- [`spec-005-daily-routine.md`](spec-005-daily-routine.md) — Daily Routine scheduler.
- **[`spec-006-privacy-behaviour-boundaries.md`](spec-006-privacy-behaviour-boundaries.md)** — Mandatory Privacy Spec (D-006 enforced).
- **[`spec-007-skill-stub.md`](spec-007-skill-stub.md)** — Skill protocol stub (Phase 7 will replace) — D-006 cross-deliverable.

---

## 3. Out of Scope (Phase 6)

- ❌ Claude integration — Phase 7.
- ❌ Skill implementations — Phase 7 (cross-deliverable per D-006).
- ❌ Polymorphic / multi-agent — Phase 9 / Future.
- ❌ Polished UI — Phase 9.

---

## 4. Privacy Spec Mandate (D-006)

Phase 6 ships the privacy contract that **all subsequent phases must honor**:

- `Entity.visibilityClass: .public | .private | .sensitive` mapping (Phase 5 data model + Phase 6 mapping).
- Default-deny map: `read_screen`, OCR, clipboard exposure, look-into-private-applications — all NO-GO.
- These are **enforced** by the Boundary Guard, a Runtime module that wraps Skill invokes and rejects any attempt to surface `.sensitive` content to Intent / IPC / Chat.

Per **D-006**, this Privacy Spec is mandatory and its acceptance items are tested in every subsequent Phase.

---

## 5. Skill Cross-Deliverable (D-006)

Per **D-006**, Phase 6 ships `DPBehavior.Skill` as a **stub** — a protocol declaration with no concrete conformers in Phase-6 source. Phase 7 (`spec-004-skill-runtime.md`) ships the real registry + lifecycle + permissions. Phase-6 acceptance row: `DPBehavior.Skill` exists as a public protocol; the Phase-6 module source has zero conformers to it (reflection test).

---

## 6. Risk (placeholder — to be expanded at Phase-6 kickoff)

- **Utility AI scoring determinism** — Mitigation: scoring is a pure function over Emotion × Time-of-day × Recent-Memory; same inputs → same Decision.
- **Memory write contention** — Mitigation: SQLite with WAL mode; one writer at a time.
- **Emotion drift** — Mitigation: bounded rates (e.g. Energy decays ≤ 0.05 / minute to a floor of 0.1).
- **Privacy violations via future Phase** — Mitigation: Boundary Guard wraps every Skill invoke; tests assert compliance per Phase.

---

## 7. Acceptance (placeholder — 4-category form finalized in `acceptance.md`)

See [`acceptance.md`](acceptance.md). Cumulative Phase-6 memory delta target: **≤ 4 MB** on top of Phase-5 baseline (≤ 164 MB worst-case at end-of-Phase-6). Profiler `.everyFrame` overhead ≤ 0.5 ms / frame (Phase-1 row 24).

---

## 8. Cross-References

- **Phase 4**: `spec-001-blendtree.md` (Animation Layer consumed by Behavior expression).
- **Phase 5**: `spec-001-desktop-discovery.md` (EntityCatalog consumed by Privacy Spec visibilityClass mapping).
- **Phase 7**: `spec-004-skill-runtime.md` (Phase-7 fills real Skill Runtime; D-006 cross-deliverable).
- **ADRs**: D-006, D-008, D-013.
