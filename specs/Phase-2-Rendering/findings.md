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

## spec-002a (asset pipeline)

| Spec text / expectation | Code reality | Rationale |
|---|---|---|
| spec-002 `DecodedModel.materials[i]` | `GLBAsset.materials: [MaterialData]` (new field). Phase-1 GLBDecoder returned `textures: []` and parsed no materials. | Phase-1 asset pipeline was skeleton/animation-only; 2a completes material parsing. |
| spec-002 `Material.fromGlb(materialIndex:)` | `Material.fromGlb(_:assetKey:materialIndex:cache:)` — `assetKey` scopes the texture cache; defined as an `extension DPRenderer.Material` in DPAsset. | `DPRenderer` is below `DPAsset` in the dep graph (DPAsset→DPRenderer), so `DPRenderer` cannot import `GLBAsset`; the factory must live in DPAsset. `assetKey` added for cache scoping. |
| spec-002 Material channels (albedo/metallic/roughness/normal/ao/emissive) | normal/ao/emissive made OPTIONAL (`nil`); `missingChannel` fires only for required albedo/metallic/roughness. | fox.glb has only `baseColorTexture` + metallic/roughness factors — no normal/AO/emissive. |
| spec-002 acceptance `albedo (0.85,0.55,0.30) SRGB` (color) | fox.glb albedo is a `baseColorTexture` (texture), not a `baseColorFactor` color. `Material.albedo: ColorOrTexture` supports both; fox is `.texture`. | Asset-specific; the spec's color reference does not match fox.glb. |
| spec-002 `SkinnedMesh` renderable geometry | Phase-1 `SkinnedMesh` had only joints/weights. 2a adds `positions`/`texcoords`/`indices` (default `[]` for back-compat). | Phase-1 geometry parsing was stubbed; 2a completes it. |
| fox.glb geometry is NON-INDEXED | fox.glb's mesh primitive has no `indices` key. `mesh.indices` stays empty; `mesh.indexCount` = 0. | Note for 2b: the renderer must use `drawPrimitives` (non-indexed), not `drawIndexedPrimitives`. |
| NORMAL attribute absent | fox.glb has no NORMAL accessor. 2a parses only present attributes. | Note for 2b: vertex shader must compute or default normals. |
| Phase-1 acceptance "decoder output unchanged" | 2a adds fields additively. fox fixture test gains NEW assertions; existing assertions untouched. | Regression-as-correction — Phase-1 decoder was intentionally minimal. |
| Minor: `readPositions`/`readTexcoords` bounds | These helpers do not guard `bvIdx < bufferViews.count` (only `readIndices` does). Crash risk only on malformed glTF referencing a non-existent bufferView. | Deferred hardening; fox.glb is well-formed. |

## spec-002b (vertex pipeline + basic render)

| Spec text / expectation | Code reality | Rationale |
|---|---|---|
| spec-002 `MaterialPass` encodes into a command buffer | `RenderPass.encode(into: MTLRenderCommandEncoder, ...)` — the shell (Phase1Renderer) owns the encoder (view rpd + clear + present); passes encode into it. spec-001's `encode(into: MTLCommandBuffer)` evolved. | Correct Metal pattern; spec-001's command-buffer form was an idealized stub. spec-001 device tests + TestPass updated. |
| Shader compilation | `MTLDevice.makeLibrary(source:options:)` at runtime; vertex + fragment compiled as SEPARATE libraries (each defines its own `VertexOut` — no concatenation/redefinition). | SwiftPM doesn't compile `.metal`; runtime string keeps `swift test`/CI intact. Separate libraries avoid the VertexOut redefinition error. |
| spec-002 `SkinnedMesh` renderable | fox.glb is NON-INDEXED (no `indices` key, 2a finding). `MaterialPass` uses `drawPrimitives` (not `drawIndexedPrimitives`). | 2a finding carried forward. |
| spec-002 PBR / lighting | 2b is UNLIT (no normals, no lighting). fox.glb has no NORMAL attribute. | Defer PBR + normal computation to 2c. |
| spec-002 GPU skinning | 2b renders bind-pose (static). `AnimationState.skinningPose` ignored. | Defer GPU skinning to 2c. |
| Application boot order (spec-003) | Device creation moved BEFORE `bootAll` (was after). | FoxRenderModule needs the device at `moduleDidBoot` to upload Metal resources. |
| Phase-1 `Camera` (position/target only) | 2b adds `viewMatrix()` (lookAt, right-handed) + `projectionMatrix(aspect:)` (Metal perspective, NDC z∈[0,1]) + fov/near/far. | Needed for the vertex shader MVP. |
| `Material.fromGlb` / `MaterialPass` cross-module | `MaterialPass` in DPRenderer (renderer-primitive handles); scene→Metal conversion in `FoxRenderModule` (DPRuntime). | DPRenderer is below DPAsset/DPRuntime — same cross-module pattern as `Material.fromGlb` (2a). |
| PNG decode Y origin | PNGDecoder's CGContext has bottom-left origin; vertex shader flips V (`1.0 - texcoord.y`). | Compensate for image-origin vs UV-origin; tunable per visual. |
| Per-frame MVP | `MaterialPassContext` captured at registration (static); per-frame MVP via a shared uniform `MTLBuffer` updated by `FoxRenderModule.moduleDidTick` each tick. | spec-001's RenderPass.Context is registration-time; per-frame data needs a separate channel. |

## Acceptance evidence (local M4 baselines)

| spec | item # | command | recorded | status |
|---|---|---|---|---|
| spec-001 | 2 | `XPETS_GPU_TESTS=1 swift test --package-path desktop-pet-core --filter RendererDeviceTests/testNoopPassDispatchP99UnderBudget` | 0.005 ms | local green |
| spec-001 | (encode order) | `XPETS_GPU_TESTS=1 swift test --package-path desktop-pet-core --filter RendererDeviceTests/testEncodeOrderMatchesRegisteredOrder` | pass | local green |
| spec-001 | (throw→drop) | `XPETS_GPU_TESTS=1 swift test --package-path desktop-pet-core --filter RendererDeviceTests/testThrowingPassDroppedAndLoopSurvives` | pass | local green |
