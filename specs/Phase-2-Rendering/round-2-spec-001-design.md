# Phase 2 · Round 2 — spec-001 (Metal Renderer backbone) Design

> **Status**: Approved design (2026-06-29) — feeds `superpowers:writing-plans`.
> **Owner**: Xavier Zhang.
> **Spec**: [`spec-001-metal-renderer.md`](spec-001-metal-renderer.md) (`Status: Approved`).
> **Execution plan**: [`execution-plan.md`](execution-plan.md) §3 (Round 2, per-spec TDD).
> **Branch (planned)**: `phase-2/spec-001-renderer`.

---

## 1. Goal

Introduce the production Metal renderer entry path: a pass-graph owner `DPRenderer.Renderer` with `RenderPass` registration, stable execution order, per-frame `currentFrameIndex`, and Profiler `Counter` integration. Replaces the Phase-1 clear-color stub with a real pass graph while preserving Phase-1 visual + regression invariants. Sits on top of existing `Phase1Renderer` (now a thin MTKView shell).

## 2. Architecture decision (locked)

**New `Renderer` (pass-graph owner, device-optional) + `Phase1Renderer` kept as shell.**

- `Renderer` is constructible without an `MTLDevice` (headless mode) → CI logic tests need no GPU.
- `Phase1Renderer` (existing `RendererSurface` / `MTKViewDelegate`) owns a `Renderer`; in `renderFrame` calls `renderer.tick(dt:)` then presents.
- The Phase-1 clear-color becomes a `ClearPass` registered as root → window stays visible (Phase-1 regression).
- Modules register passes during `moduleDidBoot` (spec: registration only legal in the module-boot window).

Chosen over folding into `Phase1Renderer` (mixes pass-graph + view-shell, violates single responsibility) and over deleting `Phase1Renderer` (largest churn, highest regression risk). `Phase1Renderer` is referenced only in `Application.init`; tests use `RendererMock` → minimal blast radius.

## 3. Components / files

| File | Action | Responsibility |
|---|---|---|
| `Sources/DPRenderer/RenderPass.swift` | new | `RenderPass` protocol (`associatedtype Context`, `func encode(into commandBuffer: MTLCommandBuffer, context: Context) -> RenderPass.ID`, `var gpuLabel: String`); `RenderPass.ID` (Hashable, Sendable; static `.root`). |
| `Sources/DPRenderer/Renderer.swift` | modify | Add `Renderer` class + `RendererError`; refactor `Phase1Renderer.renderFrame` to own a `Renderer` and call `tick`. |
| `Sources/DPRenderer/RenderPasses.swift` | new | `ClearPass` (default root; preserves Phase-1 clear color). |
| `Sources/DPRuntime/Application.swift` | modify | Wire `passGraph` to `RenderMeshModule`; register `ClearPass` at boot. |
| `Tests/DPRendererTests/RendererTests.swift` | new | Headless logic tests (no `MTLDevice`). |
| `desktop-pet-core/Package.swift` | modify | Add `DPRendererTests` test target (depends `DPRenderer`, `DPProfiler`). |
| `api/renderer-api.md` | new | Order semantics, threading contract (single Renderer thread), `MTLCommandBuffer` retain-cycle prohibition (spec deliverable). |
| `specs/Phase-2-Rendering/spec-001-metal-renderer.md` | modify | `Status: Approved → Implementing → Done` (at round close). |

## 4. `Renderer` surface (API sketch)

```swift
public final class Renderer: @unchecked Sendable {
    public init(device: MTLDevice? = nil)      // nil = headless (CI logic tests)
    public private(set) var currentFrameIndex: UInt64   // 0 at init; +1 per tick
    public private(set) var isRunning: Bool             // false until first tick
    public private(set) var registeredPassIDs: [RenderPass.ID]  // stable order

    public func registerPass(_ pass: some RenderPass, after anchor: RenderPass.ID? = nil) throws
    public func unregisterPass(id: RenderPass.ID)        // released next present tick
    public func tick(dt: Double)                          // +1 frameIndex; encode if device present
}

public enum RendererError: Error, Equatable {
    case alreadyRunning
    case duplicatePassID(RenderPass.ID)
}
```

- `registerPass` enforces `alreadyRunning` (rejects after first `tick`) and `duplicatePassID`.
- `tick(dt:)`: increments `currentFrameIndex`, sets `isRunning`, then (if `device` + `commandQueue` present) encodes each registered pass in order, recording `Profiler.shared.record(Counter(name: pass.gpuLabel, value: gpuMs))`. Headless (no device) → increments frameIndex, skips encode.
- Pass execution order is stable across frames; a pass that throws in `encode` is logged, dropped after the frame, and ticking continues (Loop survives — Phase-1 spec-003 §5 invariant).
- `RendererSurface` protocol gains `var passGraph: Renderer { get }`; `Phase1Renderer.passGraph` = its inner `Renderer`; `RendererMock.passGraph` = a headless `Renderer`.

## 5. Data flow

- **Boot**: `Application.run` → `moduleManager.bootAll` → `RenderMeshModule.moduleDidBoot` registers `ClearPass` as root via the injected `passGraph`. `Phase1Renderer.prepare(device:)` forwards the device to its inner `Renderer`.
- **Per frame**: `MTKViewDelegate.draw(in:)` → `Phase1Renderer.renderFrame(into:dt:)` → `renderer.tick(dt:)` (frameIndex++, encode passes in order, record Profiler counters) → present drawable.
- **Unregister**: `unregisterPass(id:)` marks for release; `weak var weakPass == nil` after the next drain.

## 6. Testing (logic in CI + visual baseline local on M4)

**CI logic tests** (`Tests/DPRendererTests/RendererTests.swift`, headless — `Renderer(device: nil)`):
- Register A→B→C→D → `registeredPassIDs == [.root, A, B, C, D]`; unregister B → `[.root, A, C, D]`.
- `currentFrameIndex == 0` at init; `+1` per `tick(dt:)` (headless tick, no encode).
- Register after first `tick` → `RendererError.alreadyRunning`.
- Re-register same ID → `RendererError.duplicatePassID`, original preserved.
- `unregisterPass` → `weakPass == nil` after drain.
- Profiler `Counter` recorded with correct `gpuLabel` after a tick with a test pass.

**Local M4 baseline** (not CI; recorded in `acceptance.md` Evidence):
- no-op Pass GPU P99 ≤ 0.5 ms over 600-frame window (real device).
- Real encode order matches `registeredPassIDs`.

**Phase-1 regression**: all 30 existing tests still pass; window still shows clear color (ClearPass root).

## 7. Error handling

- `RendererError.alreadyRunning` — register after first `tick`.
- `RendererError.duplicatePassID` — same ID registered twice; original ID preserved.
- `encode` throw — Renderer logs, drops the pass after the frame, continues ticking (Loop survives).

## 8. Spec ↔ code drift (logged in `findings.md` at round close)

- spec-001 references `DPRenderer.Renderer.drawClear(_:)` and `Profiler.shared.recordCounter`; neither exists. `drawClear` is replaced by the `ClearPass` root pass; `recordCounter` → actual API `Profiler.shared.record(_ counter: Counter)`. Both deviations implemented against the real Phase-1 code and recorded in `findings.md`.

## 9. Out of scope (Phase 2, but other specs)

- PBR material pass → spec-002. Lighting → spec-003. Shadow → spec-004. HDR post → spec-005.
- Render-route decision (offscreen vs direct-on-window) → Phase 5a.

## 10. Exit criteria (spec-001 round close)

- `spec-001` `Status: Done`; CI logic tests green; Phase-1 30/30 regression green.
- Local M4 no-op P99 baseline ≤ 0.5 ms recorded in `acceptance.md` Evidence.
- Memory delta ≤ 15 MB (Renderer pass/command-buffer pool) on Phase-1 65 MB baseline.
- `api/renderer-api.md` written.
