# Module Layout

> Canonical module boundaries for the desktop-pet-core Swift Package. The package follows the layered diagram in `architecture/overview.md`.

---

## Module Dependency Graph

```
DPFoundation (leaf, no internal deps)
  ↑
  ├── DPWindow
  ├── DPRenderer ──→ DPWindow
  ├── DPProfiler
  │
  └── DPAsset ──→ DPRenderer (for resource upload paths)
       ↑
       └── DPAnimation ──→ DPAsset
  ↑
DPRuntime  ← (top-level)
```

---

## Each Module's Contract

| Module | Owns | Does NOT own |
|---|---|---|
| **DPFoundation** | Logger, Config, common type definitions (vec3/vec4/quat), `RuntimeModule` protocol | Anything GPU, anything UI |
| **DPWindow** | `NSWindow` wrapper (transparent/borderless/always-on-top/click-through), multi-display, DPI | MTLView, Render |
| **DPRenderer** | `MTKView` handoff, Render pass registration, frame submission, GPU time sampling | Skeleton / Animation logic; Asset load |
| **DPAsset** | GLB + KTX2 + Shader decoders, async loader, memory + disk cache (Phase 1: memory only) | Animation clip sampling; rendering of asset |
| **DPAnimation** | Skeleton, Animation clip, Animator tick, GPU skinning | Lighting, physics |
| **DPProfiler** | Frame Pacing / GPU time / Memory / Aggregator | Sampling policy enforcement (only metrics offered) |
| **DPRuntime** | Application, Scene, UpdateLoop, EventLoop, ModuleManager, ShutdownCoordinator | Concrete modules — those register themselves |

---

## `RuntimeModule` Protocol

Every module in `DP*` conforms to `RuntimeModule` (defined in `DPFoundation`):

```
protocol RuntimeModule {
    var name: String { get }
    var dependencies: [String] { get }     // topological
    func moduleWillBoot(ctx: Context) throws
    func moduleDidBoot(ctx: Context) throws
    func moduleWillTick(dt: TimeInterval) throws
    func moduleDidTick(dt: TimeInterval) throws
    func moduleWillShutdown(ctx: Context) throws
}
```

Modules register themselves with `ModuleManager` at boot. Failures are isolated per-module (D-001 microresilience).

---

## Status

**Active**. Phase 1 implements all 7 modules with at least the boot/tick skeleton. Per-phase module surface expansion tracked in `specs/Phase-N-*/`.
