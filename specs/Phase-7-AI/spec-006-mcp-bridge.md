<!--
Status: Draft
Phase: 7 — AI
Owner: TBD
Depends: spec-002-claude-ipc.md, spec-004-skill-runtime.md
-->

# SPEC-006 — MCP Bridge (Claude Tool Calling → Skill)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> Wraps Claude's Tool Calling protocol so a Claude tool is mapped to a Skill; Claude emits a tool call → the runtime resolves to a Skill → produces an Intent → Phase 5 mutates. The reverse direction (Skill result → Claude) is also defined here.

---

## 1. Goal

Bridge Claude's MCP-style Tool Calling protocol with the Skill runtime. After SPEC-006 ships, the Pet can use Claude's Tools via Skills without requiring Skill-specific code on the Claude side; the bridge auto-converts tool names to Skill names and arguments to SkillArguments.

---

## 2. Deliverables

- `DPAI.MCPBridge`:
  - `func bridge(_ toolCall: ClaudeToolCall) async throws -> SkillResult`.
  - `func registerSkillMapping(_ name: String, skillName: String)` — reserved for Phase 9 Marketplace; Phase-7 ships with default mappings.
  - Tool permission gate: tools whose required permission is denied fail with `IntentResult.failure(.permissionDenied)`.
- Default tool→skill mappings (Phase 7):
  - `move_pet` → `MoveSkill(..)`.
  - `look_at` → `LookAtSkill(..)`.
  - `speak_text` → `SpeakSkill(..)`.
  - `play_animation` → `PlayAnimationSkill(..)`.
  - `open_app` → `OpenAppSkill(..)`.
  - `jump` → `JumpSkill(..)`.
- Tests:
  - Unit: `ClaudeToolCall(name: "move_pet", args: ["target": …])` → `MoveSkill.invoke(...)`.
  - Unit: tool name `unmapped_tool` → throws `IntentResult.failure(.unknownTool)` (Failure Mode Matrix).
  - Unit: `read_screen` is **default-denied** regardless of Claude's request (Phase-6 Privacy: never let Claude OCR anything).
- **API docs**: `api/mcp-bridge-api.md` — default mappings, security policy (`read_screen` denial default), error envelope.

---

## 3. Out of Scope

- ❌ Two-way MCP persistence — Phase 9.
- ❌ Custom user-authored Tools — Phase 9 Marketplace adds.

---

## 4. Risk

- **Tool argument schema drift** (Claude evolves MCP schema) — Mitigation: tool-args type-checked via Codable; new schema fields emit `IntentResult.failure(.unknownArg)` and don't crash.
- **read_screen** being mistakenly granted — Mitigation: hard-coded deny at MCPBridge level; tests assert no path can grant this.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- `bridge(toolCall:)` P99 ≤ 5 ms.
- Memory delta ≤ 0.5 MB.

### Enumerable use case

- 6 default mappings → all 6 work.
- `unmapped_tool` → failure.
- `read_screen` always denied.

### Assertable state

- The deny-policy for `read_screen` is a `static let` in the source — cannot be modified at runtime.
- Default mappings are immutable at boot; Phase 9 may extend.

### Previous-Phase regression

- Phase 1..6 Acceptance still pass.
- Phase-6 Privacy visibility contract is respected: Claude never receives OCR data.
