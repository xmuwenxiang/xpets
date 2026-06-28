# AI Runtime — Claude ↔ Intent ↔ Skill

> How Claude CLI, Runtime, Skill Runtime, and Behavior fit together. **Phase 7** is the primary owner; Phase 6 contributes the Skill stub.

---

## High-Level Flow

```
┌────────────┐         ┌────────────┐         ┌────────────┐
│            │ Intent  │            │ Skill    │            │
│ Claude CLI ├────────►│  Runtime   ├────────►│ Skill      │
│            │         │  Intent    │         │ Registry   │
│            │         │  Executor  │         │            │
└─────┬──────┘         └─────┬──────┘         └────┬───────┘
      │ stream               │ dispatch           │
      │ reasoning            ▼                    ▼
      │              ┌─────────────┐      ┌─────────────────┐
      └─────────────►│  Behavior   │      │ Skill body      │
                     │  Decision   │      │ (Move/Jump/…)   │
                     │  (local)    │      │                 │
                     └─────┬───────┘      └────────┬────────┘
                           │ Animation          │
                           │ / Physics          ▼
                           │             Phase 3+ subsystems
                           ▼
                       Render Frame
```

---

## IPC — Phase 7

- Transport: **Unix Domain Socket** (one-way stream from Claude → Runtime; bidirectional control via JSON-RPC).
- Wire format: NDJSON per intent. Each Intent has a stable correlation ID.
- Skill invocation: bidirectional — Runtime sends `Skill.call(name, args)`; Claude emits reasoning only.
- IPC worker has a `lastSeenTimestamp` watchdog; silence ≥ 30 s triggers Failure-Mode-Matrix entry (D-007).

---

## Failure Mode Matrix (D-007)

At minimum five Failure Modes are codified in `specs/Phase-7-AI/spec-NNN-failure-mode-matrix.md`:

1. Network offline → local Behavior fallback + idle animation cues.
2. Token exhausted → toast + return to local.
3. Anthropic 5xx → exponential backoff (max 4 retries).
4. Tool Permission denied → Skill rejects; Intent aborts gracefully; Pet shows confused state.
5. Intent parse failure (malformed JSON) → local retry; 3 fails → fallback.

---

## Privacy (Phase 6 ↔ Phase 7 boundary)

Claude **never** receives OCR of screen content, file contents, or window titles. Per Phase 6 Privacy Spec, only structured events (Pet's understanding of state) cross the IPC boundary.

---

## Status

**Stub**. Detailed IPC protocol fills at Phase 7 start. Phase 6 Skill stub is the lightweight precursor.
