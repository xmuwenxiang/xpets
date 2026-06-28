<!--
Status: Draft
Phase: 7 — AI
Owner: TBD
Depends: spec-002-claude-ipc.md, spec-004-skill-runtime.md
-->

# SPEC-003 — Intent Executor (DSL → Skill Dispatch)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> Maps Claude's emitted Intents into typed Skill invocations.

---

## 1. Goal

Define a small Intent DSL that Claude emits; bind each Intent kind to a Skill in the Phase-6 Skill stub (`spec-004-skill-runtime.md`). After SPEC-003 ships, an Intent of kind `.speak` routes to the `SpeakSkill`; `.move` to `MoveSkill`; the executor is a pure function with no side-effects on Phase-5 AnimationDriver until the Skill is invoked.

---

## 2. Deliverables

- `DPAI.Intent`:
  ```swift
  enum Intent {
      case speak(text: String)
      case move(target: SIMD3<Float>, speed: Float)
      case jump
      case playAnimation(name: String)
      case lookAt(target: SIMD3<Float>)
      case openApp(bundleID: String)
      case rawToolCall(ClaudeToolCall)   // pass-through to spec-006
  }
  ```
- `DPAI.IntentExecutor`:
  - `func execute(intent: Intent, in: SkillContext) async throws -> IntentResult`.
  - Each case routes to a Skill registered in `SkillRegistry` (Phase-6 spec-004).
  - Failure modes (parse error, missing skill) → emits `IntentResult.failure(reason)`, propagates to Failure Mode Matrix (`spec-008`).
- Conversation context: a `ConversationContext` carries the current pet-state history (last 5 turns) for speak Skills.
- Tests:
  - Unit: 7 intent cases each route to the correct Skill registration.
  - Unit: missing-skill case emits `IntentResult.failure(reason: .skillMissing)`.
  - Unit: malformed intent (test fixture) emits `IntentResult.failure(reason: .parseError)`.
- **API docs**: `api/intent-api.md` — Intent cases, executor threading, ConversationContext shape.

---

## 3. Out of Scope

- ❌ Tool Calling protocol — `spec-006-mcp-bridge.md`.
- ❌ Skill registry internals — `spec-004-skill-runtime.md`.
- ❌ Multi-turn conversation summarization — Phase 9.

---

## 4. Risk

- **Side-effect ordering** (Speak before Move) — Mitigation: intents are serial-by-default; concurrent intents require explicit `ConcurrentBatch` wrapping.
- **Intent DSL drift vs Claude's actual output** — Mitigation: parsing falls back to `rawToolCall` if Intent DSL fails to match — Claude Tool Calling (`spec-006`) is the safe fallback path.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- `IntentExecutor.execute` P99 ≤ 5 ms / intent (excludes Skill cost).
- Memory delta ≤ 0.5 MB.
- Profiler budget unchanged.

### Enumerable use case

- 7 intent cases routed correctly.
- Missing-skill → `IntentResult.failure(.skillMissing)`.
- Malformed → `IntentResult.failure(.parseError)`.
- Round-trip: Claude emits `.move`, pet slides to target via `Phase5AnimationDriver`.

### Assertable state

- `Intent` is `Codable`; round-trip stable.
- `IntentExecutor` is stateless (one instance shared).
- `ConversationContext` carries a typed list of recent turns.

### Previous-Phase regression

- Phase 1..6 Acceptance still pass.
- Phase-5 AnimationDriver untouched by Phase 7 logic at the wire level.
