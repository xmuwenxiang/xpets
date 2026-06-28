# DPRuntime API

> Module: `DPRuntime` · Owner Phase: 1
> Related: `architecture/lifecycle.md`, `architecture/threading-model.md`

---

## Public Surface

```
public protocol RuntimeModule {
    var name: String { get }
    var dependencies: [String] { get }
    func moduleWillBoot(ctx: Context) throws
    func moduleDidBoot(ctx: Context) throws
    func moduleWillTick(dt: TimeInterval) throws
    func moduleDidTick(dt: TimeInterval) throws
    func moduleWillShutdown(ctx: Context) throws
}

public final class Application {
    public init(configuration: Config) throws
    public func run() async -> Int32  // 0 = success
}

public final class Scene {
    public private(set) var assets: AssetRegistry
    public private(set) var animationState: AnimationState
    public private(set) var camera: Camera
    public private(set) var profiler: ProfilerHandle
}

public final class UpdateLoop {
    public init(modules: [RuntimeModule], profiler: ProfilerHandle)
    public func start() throws
    public func stop() async
}

public final class ModuleManager {
    public func register(_ module: RuntimeModule) throws
    public func errorIsolated(_ module: RuntimeModule) -> Bool
}

public final class ShutdownCoordinator {
    public func registerShutdown(_ handler: @escaping () async throws -> Void)
    public func executeShutdown() async
}
```

## Invariants

- `Application.run()` returns only after `ShutdownCoordinator.executeShutdown()` completes.
- A module's `moduleWillTick` is invoked synchronously on the Update thread.
- A module that throws in `moduleWillTick` does **not** halt the loop (the loop marks it `degraded` and skips subsequent ticks for that module).
- `Scene` exposes **read-only** views post-boot; mutation goes through dedicated controllers.

## Error Modes

| Method | Throws |
|---|---|
| `Application.init` | `ConfigError`, `ModuleRegistrationError` |
| `Register` | `ModuleDepsError` (missing declared deps) |
| `moduleWillBoot` | Module-specific |
| `UpdateLoop.start` | `MetalInitError` (from Renderer integration) |
| `Shutdown` | Tolerant: log + continue |

## Test Hooks

- `MockModule` (in tests): fake module that throws on demand.
- `LoopTester` (in tests): pumps deterministic `dt`.
- `SceneSpy` (in tests): captures post-tick Scene snapshot.

## Status

**Stub**. Filled when `spec-003-runtime.md` lands; Swift signatures finalized in implementation Phase 1.
