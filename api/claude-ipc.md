# Claude IPC API

> Phase: 7 (AI)
> Related: `architecture/ai-runtime.md`, D-007 (Failure Mode Matrix)

---

## Transport

- **Unix Domain Socket**
- Path: `<user-specific>/Library/Application Support/DesktopPet/claude.sock`
- One socket per Claude process invocation.

## Wire Format (NDJSON)

Each line is one JSON object. Two top-level shapes:

### Runtime → Claude

```
{
  "kind": "context",
  "sessionId": "uuid",
  "sceneSnapshotRef": "obs://scene/uuid",
  "lastUserIntent": "Move",
  "memoryRef": "obs://memory/recent",
  "failureMode": null
}
```

### Claude → Runtime

```
{
  "kind": "intent",
  "id": "uuid",
  "name": "Move",
  "args": {"target": [x, y]},
  "toolCalls": [
    {"name": "Speak", "args": {"text": "hi"}}
  ]
}
```

## Failure Mode (D-007 ≥5 scenarios)

| Scenario | Runtime Behavior |
|---|---|
| Network offline | Drop Claude; emit local Behavior; idle animation |
| Token exhausted | Backoff + toast; local fallback |
| Anthropic 5xx | Exponential backoff, max 4 retries |
| Tool permission denied | Skill rejects; Intent aborts; confused-state anim |
| Intent parse failure | Local retry; 3 fails → fallback |

## Privacy (Phase 6 ↔ 7 boundary)

Claude **never receives** OCR, file contents, screen pixels, or window titles. Only structured `context` blobs.

## Status

**Stub**. Filled at Phase 7 start.
