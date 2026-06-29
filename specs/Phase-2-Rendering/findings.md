# Phase 2 — Findings (spec ↔ code drift)

> Logged during Round 2 implementation. Each entry: spec text → code reality → rationale.

## spec-001

| Spec text | Code reality | Rationale |
|---|---|---|
| `DPRenderer.Renderer.drawClear(_:)` | No such method existed in Phase 1 (only `Phase1Renderer.renderFrame`). spec-001 introduces `Renderer` + `ClearPass`. The on-screen clear stays in `Phase1Renderer.renderFrame` for spec-001; `ClearPass.encode` is a no-op. | spec was written against an idealized API; minimal-churn reconciliation (Option A design). |
| `Profiler.shared.recordCounter` | `Profiler.shared.record(_ counter: Counter)` is the actual API. `Renderer` does not call it directly — `DPProfiler` already depends on `DPRenderer`, so a direct call would be a circular dependency. `Renderer.counterSink: ((String, Double) -> Void)?` is injected; `Application` wires it to `Profiler.shared.record`. | Architectural correctness; preserves the dependency graph. |
| `Renderer.tick(_:)` | `Renderer.tick(dt: Double, into commandBuffer: MTLCommandBuffer? = nil)`. | Headless CI tests need a no-encode path (`into: nil`); device tests / future passes pass a real buffer. |
| `registerPass(_ pass: RenderPass, after:)` | `registerPass<P: RenderPass>(_ pass: P, context: P.Context, after:)`. | `RenderPass.associatedtype Context` requires the context at registration for `AnyRenderPass` type-erased storage. |
| "first pass becomes `RenderPass.ID.root`" | `RenderPassId.root` is a fixed static ID; `ClearPass` registers with `.root`. | Static `.root` is simpler and matches the spec's `RenderPass.ID.root` notation. |
| `RenderPass.ID` (spec notation) | `RenderPassId` (Swift type name). | Swift naming convention; the spec's dotted notation is conceptual. |

### Accepted gaps (not test-asserted)

| Spec acceptance row | Reality | Rationale |
|---|---|---|
| spec-001 §5 row 6 — "`MTLDevice` reference count in process = 1 (asserted via `gpuCount` test fixture)" | No `gpuCount` fixture exists. The invariant holds **by construction**: `Renderer` never calls `MTLCreateSystemDefaultDevice` (it receives the device via `attach(device:)`); the only such call in the codebase is in `Application.run`. Verifiable by `grep -rn MTLCreateSystemDefaultDevice desktop-pet-core/Sources` (single hit), not by a runtime refcount test. | Process-level `MTLDevice` refcount is not introspectable from Swift without invasive plumbing; the structural guarantee + grep check is the pragmatic gate. Not CI-test-asserted. |
| spec-001 §5 — "`Counter(name: gpuLabel, value: gpuMs)`" | `counterSink` is called with `value: 0` (not measured `gpuMs`). | Real GPU-time (`gpuStartTime`/`gpuEndTime`) instrumentation is a Phase-6 hook per the Phase-1 `Phase1Renderer.renderFrame` comment; spec-001 records the dispatch signal (name) only. Value wiring lands with Phase 6 GPU-time readout. |

## Acceptance evidence (local M4 baselines)

| spec | item # | command | recorded | status |
|---|---|---|---|---|
| spec-001 | 2 | `XPETS_GPU_TESTS=1 swift test --package-path desktop-pet-core --filter RendererDeviceTests/testNoopPassDispatchP99UnderBudget` | 0.005 ms | local green |
| spec-001 | (encode order) | `XPETS_GPU_TESTS=1 swift test --package-path desktop-pet-core --filter RendererDeviceTests/testEncodeOrderMatchesRegisteredOrder` | pass | local green |
| spec-001 | (throw→drop) | `XPETS_GPU_TESTS=1 swift test --package-path desktop-pet-core --filter RendererDeviceTests/testThrowingPassDroppedAndLoopSurvives` | pass | local green |
