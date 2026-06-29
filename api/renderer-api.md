# Renderer API (Phase 2 — spec-001)

> The Metal renderer pass-graph. Implements `specs/Phase-2-Rendering/spec-001-metal-renderer.md`.

## Surface

`DPRenderer.Renderer` — the pass-graph owner. Constructible with `MTLDevice?` (nil = headless for CI logic tests).

| Member | Purpose |
|---|---|
| `init(device: MTLDevice? = nil)` | Boot. Device optional; `attach(device:)` fills it post-boot. |
| `var currentFrameIndex: UInt64` | Monotonic per-frame counter; 0 at init, +1 per `tick`. |
| `var isRunning: Bool` | False until first `tick`; gates `registerPass`. |
| `var registeredPassIDs: [RenderPassId]` | Stable execution-order snapshot. |
| `var counterSink: ((String, Double) -> Void)?` | Injected Profiler sink (Renderer cannot import DPProfiler — circular dep). Runtime wires to `Profiler.shared.record`. |
| `registerPass(_:context:after:)` | Register during module-boot window only. `after` anchors insertion. |
| `unregisterPass(id:)` | Deferred release on next `tick`. |
| `tick(dt:into:)` | Advance frame; encode passes into the given `MTLCommandBuffer` if provided; emit Counter per pass. |

## Order semantics

- Pass execution order = registration order; stable across frames.
- `unregisterPass` is deferred to the next `tick` (no use-after-free mid-frame).
- A pass whose `encode` throws is dropped after the frame; ticking continues (Loop-survives invariant, Phase-1 spec-003 §5).

## Errors

`RendererError.alreadyRunning` — register after first `tick`. `RendererError.duplicatePassID(RenderPassId)` — same ID twice; original preserved.

## Threading contract

- Single Renderer thread. `RenderPass.Context` must be `Sendable` if it crosses threads.
- `MTLCommandBuffer` retain-cycle prohibition: passes must not retain the command buffer beyond the `tick` in which it was provided; the Runtime commits the buffer each frame.

## spec ↔ code drift (see findings.md)

- `drawClear(_:)` (spec) → `ClearPass` root pass (no on-screen clear duty in spec-001; Phase-1 clear stays in `Phase1Renderer.renderFrame`).
- `Profiler.shared.recordCounter` (spec) → `counterSink` injection → `Profiler.shared.record(_:)` (circular-dep avoidance).
- `tick(_:)` (spec) → `tick(dt:into:)` (default `into: nil` = headless).
- `registerPass(_:after:)` (spec) → `registerPass(_:context:after:)` (context captured at registration for type-erased storage).