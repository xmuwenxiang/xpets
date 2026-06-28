# DPProfiler API

> Module: `DPProfiler` · Owner Phase: 1 (per D-008)
> Related: `specs/Phase-1-Foundation/spec-006-profiler.md`, D-013 (4-category Acceptance)

---

## Public Surface

```
public final class Profiler {
    public static let shared: Profiler
    public var samplingPolicy: SamplingPolicy
    public func start()
    public func stop()
    public func frameCompleted(_ stats: FrameStats)
    public func memorySample(_ s: MemorySample)
    public func counter(_ name: String, _ value: Double)
}

public enum SamplingPolicy {
    case off
    case everyFrame
    case everyNFrames(Int)
    case manual
}

public struct FrameStats {
    public let dt: TimeInterval
    public let cpuMs: Double
    public let gpuMs: Double
    public let droppedFrames: Int
}

public struct MemorySample {
    public let residentMB: Double
    public let footprintMB: Double
}
```

## Performance Invariants

- `.off`: zero allocations per frame.
- `.everyFrame`: ≤ 0.5 ms CPU overhead (per `spec-006-profiler.md` Acceptance 24).
- Rolling window: ≤ 600 frames; emitting every 1 s.

## Test Hooks

- `ProfilerSpy`: captures each `frameCompleted` call.
- `AllocationTracker` (in tests): asserts zero heap allocations in `.off`.

## Status

**Stub**. Filled when `spec-006-profiler.md` lands.
