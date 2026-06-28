<!--
Status: Draft
Phase: 7 — AI
Owner: TBD
Depends: spec-001-claude-runtime.md, spec-003-intent-executor.md
-->

# SPEC-007 — Chat Panel (Streaming UI Shell)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> A minimal chat panel that streams Claude's output to the user. Phase 9 will polish; Phase 7 ships the working shell.

---

## 1. Goal

Provide a small text panel that displays streaming text from Claude as it arrives. After SPEC-007 ships, the user can see Claude's response in real time, with a Refresh button for re-asking and a Stop button for cancelling.

---

## 2. Deliverables

- `DPAI.ChatPanel`:
  - SwiftUI view rendering streaming text.
  - Subscribes to `ClaudeSession.events` (`spec-002`).
  - Stop button: emits `claudeRuntime.stop()`.
  - Refresh button: re-sends the last prompt.
- Refresh-policy: ≤ 1 RPS, with debounce.
- Tests:
  - UI test using `XCUIApplication`: click Refresh → assert text repopulates within 1 s.
  - UI test: click Stop while Claude is streaming → text is frozen mid-stream.
- **API docs**: `api/chat-panel-api.md` — minimum viable UI; deferred items list (Phase 9).

---

## 3. Out of Scope

- ❌ Rich text formatting, Markdown, syntax highlight — Phase 9.
- ❌ persistent chat history on disk — Phase 9.
- ❌ Multi-tab chat — Phase 9.

---

## 4. Risk

- **Streaming text buffer overflow** — Mitigation: streaming chunk size capped at 512 bytes; older chunks trimmed.
- **Refresh spam** — Mitigation: 1 RPS debounce.
- **Text encoding corruption** during pause/resume — Mitigation: text is UTF-8 fixed; tested with unicode boundary edges.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- Streaming text rendering P99 ≤ 16 ms / frame on M2.
- Memory delta for chat panel ≤ 2 MB.
- Profiler budget unchanged.

### Enumerable use case

- Refresh click → text populates within 1 s.
- Stop click mid-stream → frozen text.
- 10 RPS click spam → only 1 RPS honored.

### Assertable state

- `ChatPanel` cleanly detectable via XCUITest accessibility.
- Stop/Refresh buttons have stable accessibility identifiers.
- UTF-8 boundary test passes.

### Previous-Phase regression

- Phase 1..6 Acceptance still pass.
- Phase-1 Overlay window unaffected (chat panel slides out from the side).
