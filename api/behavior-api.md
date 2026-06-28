# Behavior API

> Module: `DPBehavior` (introduced Phase 6; `architecture/ai-runtime.md`)
> Owner Phase: 6 (Behavior) + 7 (AI bridge)

## Public Surface (Phase 6 — stub)

```
public final class BehaviorRuntime {
    public init(scene: Scene, skills: SkillRegistry)
    public func tick(dt: TimeInterval)
    public func currentEmotion() -> EmotionState
    public func dailyRoutineAt(_ date: Date) -> [BehaviorTask]
}

public protocol Skill {
    var name: String { get }
    var permission: Permission { get }
    func invoke(_ intent: Intent) async throws -> SkillResult
    func cancel() async
}

public final class SkillRegistry {
    public func register(_ s: Skill)
    public func invoke(name: String, intent: Intent) async -> SkillResult
}
```

## Phase 7 additions

- `ClaudeBridge`: emits Intent to Claude CLI via UnixSocket; receives Skill calls.
- `FailureModeMatrix`: codified fallback per D-007 ≥5 scenarios.

## Status

**Stub**. Phase 6 ships Skill stub (D-006); Phase 7 fills body.
