# Phase 6 — Behavior

> **Status**: Stub — Phase 5 closure gating begins content authoring.
> **Goal**: Make the fox feel alive. Utility AI scores behavior (Sleep / Eat / Play / Observe / Talk / Explore). Emotion regulates Energy / Curiosity / Trust / Happiness. Memory anchors state across runtime instances. Daily Routine produces a believable rhythm.
> **Mandatory add-on**: a **Privacy & Behavior Boundaries** sub-Spec — the fox is now an always-on resident on the desktop and ethical / privacy boundaries must be defined before any Decide.
> **Skill stub**: the Skill concept appears here as a stub so Phase 7 has a real extension point (D-006).

> ⚠️ **PLACEHOLDER — content authoring begins when Phase 5 closes.** Acceptance prose below is rewritten in 4-category form (D-013) at Phase 6 start.

---

## Goal (Phase 6 final)

A running fox that acts on local heuristics (no LLM). It chooses behaviors, expresses via Animation Layer (Phase 4), respects privacy boundaries, records memory, and follows a daily routine.

---

## Pre-known Deliverables (to be expanded)

- `spec-001-behavior-fsm.md` — Baseline states
- `spec-002-utility-ai.md` — Behavior scoring
- `spec-003-emotion.md` — Mood, Energy, Curiosity, Trust, Happiness
- `spec-004-memory.md` — Local Memory store (SQLite backing in Phase 6, not deferred)
- `spec-005-daily-routine.md` — Daily Routine scheduler
- **`spec-006-privacy-behaviour-boundaries.md`** — Mandatory Privacy Spec (D-006 enforced)
- **`spec-007-skill-stub.md`** — Skill protocol stub (Phase 7 will replace) — D-006

---

## Out of Scope (Phase 6)

- ❌ Claude CLI integration — Phase 7
- ❌ Failure Mode Matrix (Claude 5xx etc.) — Phase 7
- ❌ Auto Update / Crash / Telemetry — Phase 9

---

## Privacy Boundaries (mandatory Privacy Spec)

Required behavior contracts:
- Staring at unread private messages: NEVER
- Reading OCR of certain regions: BLOCKED for sensitive file paths
- Recording screenshots: NEVER (only local event summaries, never pixels)
- Audio pickup: NONE (no microphone access in Phase 6)
- Idle cycle limits: PET-FREQUENT pause after 5 min idle to honour host focus
- Presence during meetings / screen recording: configurable per-region avoidance

---

## Risk (placeholder)

- Privacy boundary violation creating user distrust
- Utility AI's weight tuning producing repetitive behavior
- Memory growth → Phase 8 hardens

---

## Acceptance (placeholder — 4 categories)

- Utility AI picks Sleep over Play when energy low and night-time
- Daily Routine varies across week
- Privacy Spec invariants enforced in tests
- Skill stub exists and is callable by Phase 6 behavior

---

## Cross-References

- Phase 1 lifecycle: Scene assets, Animation Layer driver (D-007 cross-deliver)
- Phase 4 Animation Layer (Emotion expression)
- Phase 7 Claude Skill hookup
