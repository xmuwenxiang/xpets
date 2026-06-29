# Phase 2 · Round 2b — spec-002 sub-round (Vertex Pipeline + Basic Render) Design

> **Status**: Approved design (2026-06-29) — feeds `superpowers:writing-plans`.
> **Owner**: Xavier Zhang.
> **Parent spec**: [`spec-002-material-pbr.md`](spec-002-material-pbr.md) (stays `Status: Approved` through 2b; transitions only after 2c).
> **Decomposition**: 2a (asset data, ✅Done) → **2b (this round: fox visible)** → 2c (PBR Cook-Torrance). See `execution-plan.md` §3.
> **Branch (planned)**: `phase-2/spec-002b-vertex-pipeline`.

---

## 1. Goal

Make the fox visible on the overlay window: introduce the first Metal shaders (runtime-compiled), upload the fox mesh + albedo texture to Metal resources, and a `MaterialPass` that draws a static bind-pose, unlit, textured fox each frame. This is the "fox appears" milestone. GPU skinning (animation) and PBR lighting are deferred to 2c.

## 2. Key decisions (locked)

1. **Shader strategy — runtime compile from a string.** Shader source lives as Swift string constants in `DPRenderer/Shaders.swift`, compiled via `MTLDevice.makeLibrary(source:options:)` at boot. **No `.metal` files** — SwiftPM does not compile `.metal` (would break `swift test`/CI). This keeps the test-driven, SwiftPM-only build intact.
2. **Scope — static bind-pose, unlit, textured.** Vertex shader applies model-view-projection (MVP) and passes UV; fragment shader samples the albedo texture. No skinning, no lighting. Sidesteps fox.glb's missing NORMAL attribute (unlit needs no normals). GPU skinning + PBR → 2c.
3. **`RenderPass.encode` evolution (touches spec-001 Done code).** spec-001's `encode(into: MTLCommandBuffer, context:)` → `encode(into: MTLRenderCommandEncoder, context:)`; `Renderer.tick(dt:, into: MTLRenderCommandEncoder?)`. The shell (`Phase1Renderer.renderFrame`) builds the render command encoder from the view's render-pass descriptor (the drawable owner); passes encode draw calls into that encoder. This is the correct Metal pattern (the shell owns the encoder + clear + present). spec-001's `AnyRenderPass`, `ClearPass`, and `RendererDeviceTests` are updated to the encoder-based signature. Logged as a spec-001 refinement (its command-buffer signature was an idealized stub).
4. **Per-frame MVP via a shared uniform buffer.** spec-001's `RenderPass.Context` is captured at registration (static). Per-frame data (MVP) goes through a uniform `MTLBuffer` that `FoxRenderModule` updates each tick; the `MaterialPass` reads it at encode time. The registration-time context holds static refs (vertex buffer, uniform buffer, albedo texture, pipeline state).

## 3. Architecture

`MaterialPass` (DPRenderer) holds **renderer-primitive handles only** (MTLBuffer / MTLTexture / MTLRenderPipelineState) — NO DPAsset/DPRuntime types, preserving the dep graph (DPRenderer is below DPAsset/DPRuntime). The scene→renderer-primitive conversion happens in **`FoxRenderModule`** (DPRuntime, imports DPRenderer + DPAsset): at boot it uploads the fox mesh + albedo image to Metal resources, builds the pipeline, and registers the `MaterialPass`; each tick it writes the camera MVP into the uniform buffer.

### Boot-order change (drift from spec-003/Application boot order)

`FoxRenderModule.moduleDidBoot` needs an `MTLDevice` to upload buffers/textures/build the pipeline. Currently `Application.run` creates the device in `prepare` (step 3, AFTER `bootAll` step 2). **Fix: create the device BEFORE `bootAll`** and pass it to `FoxRenderModule` at construction. `FoxRenderModule` declares a dependency on `AssetPreloadModule` (so the fox is loaded before it boots). New `Application.run` order:
1. `eventLoop.prepare`
2. create `MTLDevice` (`MTLCreateSystemDefaultDevice`)
3. `window.attach` + `renderer.prepare(device)` + counterSink wiring
4. register `RenderMeshModule` + `AssetPreloadModule` + `FoxRenderModule(device, scene, passGraph)` → `bootAll` (topo order: RenderMesh → AssetPreload → FoxRender)
5. `updateLoop.start`
6. `eventLoop.run`

Phase-1 modules are unaffected (device existing earlier is harmless; prepare still attaches it to the view).

## 4. Components / files

| File | Action | Responsibility |
|---|---|---|
| `desktop-pet-core/Sources/DPRenderer/Shaders.swift` | new | Vertex + fragment Metal source as Swift strings (unlit textured: MVP + UV passthrough + albedo sample). |
| `desktop-pet-core/Sources/DPRenderer/MaterialPass.swift` | new | `MaterialPass: RenderPass` (Context = `MaterialPassContext`); `MaterialPassContext` (vertexBuffer, uniformBuffer, albedoTexture, pipelineState, vertexCount); pipeline factory (`makeLibrary(source:)` + vertex descriptor + `MTLRenderPipelineDescriptor`). |
| `desktop-pet-core/Sources/DPRenderer/RenderPass.swift` | modify | `encode(into: MTLRenderCommandEncoder, context:) throws -> RenderPassId`; `AnyRenderPass._encode` becomes `(MTLRenderCommandEncoder) throws -> RenderPassId`. |
| `desktop-pet-core/Sources/DPRenderer/Renderer.swift` | modify | `Renderer.tick(dt:, into: MTLRenderCommandEncoder?)` (encode-if-encoder; headless `into: nil` still increments frameIndex + counters); `Phase1Renderer.renderFrame` reworked: view rpd (loadAction `.clear`) → makeCommandBuffer → makeRenderCommandEncoder → `renderer.tick(dt:, into: encoder)` → endEncoding → present → commit. Update `ClearPass`/`AnyRenderPass` for encoder signature. |
| `desktop-pet-core/Sources/DPRuntime/Scene.swift` | modify | `Camera` += perspective view + projection matrices (`viewMatrix()`, `projectionMatrix(aspect:)`). |
| `desktop-pet-core/Sources/DPRuntime/FoxRenderModule.swift` | new | `RuntimeModule`: `moduleDidBoot` uploads mesh (positions/UVs) → MTLBuffer, albedo `DecodedImage` → MTLTexture, builds pipelineState + uniform buffer, registers `MaterialPass`; `moduleDidTick` writes camera MVP into the uniform buffer. |
| `desktop-pet-core/Sources/DPRuntime/Application.swift` | modify | New boot order (§3); register `FoxRenderModule(device, scene, renderer.passGraph)`. |
| `desktop-pet-core/Tests/DPRendererTests/MaterialPassDeviceTests.swift` | new | Env-gated device tests: pipeline creates, draw doesn't crash, screenshot. |
| `desktop-pet-core/Tests/DPRendererTests/RendererDeviceTests.swift` | modify | Update for encoder-based `tick`/`encode` (make a render encoder from a texture+rpd instead of a bare command buffer). |
| `desktop-pet-core/Tests/DPRuntimeTests/CameraTests.swift` | new | Projection/view matrix math (headless CI). |

## 5. Data flow

- **Boot**: `FoxRenderModule.moduleDidBoot` (after `AssetPreloadModule`) → `scene.assetRegistry.glb` first value → upload `mesh.positions`/`mesh.texcoords` to a `MTLBuffer` (positions: SIMD3<Float>×N, texcoords: SIMD2<Float>×N); upload `images[albedoImageIndex]` (DecodedImage RGBA8) → `MTLTexture` (`MTLPixelFormat.rgba8Unorm`, `usage: .shaderRead`); build `MTLRenderPipelineState` from `Shaders` source + vertex descriptor (positions float3, texcoords float2) + view's color pixel format; create a uniform `MTLBuffer` (16×4=64 bytes for MVP float4x4); construct `MaterialPassContext`; `renderer.passGraph.registerPass(MaterialPass(ctx), context: ctx)` (registration legal — before first tick).
- **Tick**: `FoxRenderModule.moduleDidTick` → `camera.viewMatrix()` × `camera.projectionMatrix(aspect:)` × model (identity for bind pose) → write float4x4 into the uniform buffer's `contents()`.
- **Render frame**: `Phase1Renderer.renderFrame` → `view.currentRenderPassDescriptor` (loadAction `.clear`, clearColor sea-blue) → `queue.makeCommandBuffer()` → `buffer.makeRenderCommandEncoder(descriptor: rpd)` → `renderer.tick(dt: dt, into: encoder)` (MaterialPass: `setRenderPipelineState`, `setVertexBuffer(vertexBuffer)`, `setVertexBuffer(uniformBuffer)`, `setFragmentTexture(albedoTexture)`, `drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount)` — **non-indexed**, fox.glb has no index buffer) → `endEncoding` → `present(drawable)` → `commit`.

## 6. spec ↔ reality reconciliations (append to findings.md at round close)

1. **`RenderPass.encode` signature**: spec-001 `encode(into: MTLCommandBuffer, ...)` → `encode(into: MTLRenderCommandEncoder, ...)`. The shell owns the encoder (view rpd + clear + present); passes encode into it. spec-001's command-buffer form was an idealized stub; 2b corrects to the real Metal pattern. spec-001's `AnyRenderPass`/`ClearPass`/`RendererDeviceTests` updated.
2. **Non-indexed draw**: fox.glb has no index buffer (2a finding). `MaterialPass` uses `drawPrimitives` (not `drawIndexedPrimitives`).
3. **No NORMAL**: fox.glb has no NORMAL attribute. 2b is unlit (no normals needed). 2c PBR will compute/default normals.
4. **No skinning**: 2b renders bind-pose (static). `AnimationState.skinningPose` ignored. GPU skinning → 2c.
5. **Boot order**: device creation moved before `bootAll` (spec-003/Application order drift) so `FoxRenderModule` can upload Metal resources at boot.
6. **Camera projection**: Phase-1 `Camera` had only position/target. 2b adds view+projection matrices.
7. **`MaterialPass` location**: `MaterialPass` in DPRenderer (renderer-primitive handles); the scene→Metal conversion in `FoxRenderModule` (DPRuntime) — same cross-module pattern as `Material.fromGlb` (DPRenderer below DPAsset/DPRuntime).

## 7. Testing (logic in CI + visual baseline local on M4)

**CI logic tests (headless):**
- `CameraTests`: `viewMatrix()`/`projectionMatrix(aspect:)` produce sensible matrices (camera at (0,0,5) → view translates Z; projection has correct aspect/fov; MVP maps origin into clip space).
- Shader source non-empty (compile needs a device → device-gated, but source-string presence is headless).

**Local M4 device tests (env-gated `XPETS_GPU_TESTS`, skipped on CI):**
- `MaterialPassDeviceTests`: pipeline state creates (shader compiles); `tick(dt:, into: encoder)` with a real encoder + offscreen texture doesn't crash; draws `vertexCount` primitives.
- **Visual baseline**: run the interactive app, screenshot → the overlay shows the **textured fox** (not a flat color block). Recorded in `acceptance.md` evidence. (ΔE vs the Phase-1 flat block ≥ some threshold — the fox silhouette+texture appears.)

**spec-001 device tests updated** for the encoder-based signature (make a render encoder from a texture+rpd; the encode-order/throw/P99 tests still assert the same behavior via the encoder).

## 8. Phase-1 / spec-001 / 2a regression

- Phase-1 30 tests + 2a tests unaffected (asset data unchanged; Camera additive; boot order change is additive for Phase-1 modules).
- spec-001 logic tests (headless `tick(dt:)` with `into: nil`) unaffected — `tick(dt:, into: MTLRenderCommandEncoder?)` defaults to nil, headless path identical.
- spec-001 device tests updated to encoder signature — same behavior asserted.
- `phase2-spec-lint` unaffected (spec-002 stays Approved).

## 9. Exit criteria (2b round close)

- **Visual**: interactive app screenshot shows the textured fox on the overlay (the milestone).
- CI logic tests green; full suite green (Phase-1 + spec-001 + 2a + 2b; device tests skip on CI, pass on M4).
- spec-001 device tests updated + green.
- `findings.md` appended with §6 reconciliations.
- spec-002 stays `Status: Approved` (2b is a sub-round; 2c closes spec-002).

## 10. Out of scope (deferred to 2c)

- PBR Cook-Torrance fragment shader (direct lighting), IBL.
- GPU skinning (animated fox; vertex shader reads joints/weights + joint matrix buffer).
- Normal computation (fox.glb has no NORMAL; 2c derives or defaults).
- `MaterialPass` lighting uniforms (light direction, etc.).
- `api/material-api.md` (lands with 2c's PBR shader).
