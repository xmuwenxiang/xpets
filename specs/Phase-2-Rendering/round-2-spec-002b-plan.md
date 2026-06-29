# spec-002b (Vertex Pipeline + Basic Render) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the fox visible on the overlay — first Metal shaders (runtime-compiled), upload fox mesh + albedo texture to Metal resources, `MaterialPass` draws a static bind-pose unlit textured fox each frame.

**Architecture:** `MaterialPass` (DPRenderer, renderer-primitive handles) + `FoxRenderModule` (DPRuntime, scene→Metal conversion). Shader source compiled at runtime via `makeLibrary(source:)` (no `.metal` files). `RenderPass.encode` evolves to encoder-based (shell owns encoder). Per-frame MVP via a shared uniform `MTLBuffer`. Static bind-pose, unlit, textured (skinning + PBR → 2c).

**Tech Stack:** Swift 5.10 / SwiftPM / Metal 3 (M4) / `import simd` (matrix math) / XCTest.

**Branch:** `phase-2/spec-002b-vertex-pipeline` (from `main` at commit `53dabb5`).

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `desktop-pet-core/Sources/DPRenderer/RenderPass.swift` | modify | `encode(into: MTLRenderCommandEncoder, ...)`; `AnyRenderPass` adapts. |
| `desktop-pet-core/Sources/DPRenderer/Renderer.swift` | modify | `tick(dt:, into: MTLRenderCommandEncoder?)`; `ClearPass.encode` adapts; `Phase1Renderer.renderFrame` reworked (encoder + tick + present). |
| `desktop-pet-core/Sources/DPRenderer/Shaders.swift` | new | Vertex + fragment Metal source strings. |
| `desktop-pet-core/Sources/DPRenderer/MaterialPass.swift` | new | `MaterialPass` + `MaterialPassContext` + pipeline factory. |
| `desktop-pet-core/Sources/DPRuntime/Scene.swift` | modify | `Camera` += view/projection matrices (+ fov/near/far); `import simd`. |
| `desktop-pet-core/Sources/DPRuntime/FoxRenderModule.swift` | new | Boot uploads mesh+texture+pipeline+uniform, registers MaterialPass; tick writes MVP. |
| `desktop-pet-core/Sources/DPRuntime/Application.swift` | modify | Boot order: device before bootAll; register FoxRenderModule. |
| `desktop-pet-core/Tests/DPRendererTests/RendererDeviceTests.swift` | modify | Update spec-001 device tests to encoder-based signature. |
| `desktop-pet-core/Tests/DPRuntimeTests/CameraTests.swift` | new | Projection/view matrix math (headless CI). |
| `desktop-pet-core/Tests/DPRendererTests/MaterialPassDeviceTests.swift` | new | Env-gated: pipeline creates, draw doesn't crash. |
| `specs/Phase-2-Rendering/findings.md` | modify | Append 2b reconciliations. |

---

## Task 1: Evolve RenderPass.encode to encoder-based (+ update spec-001 device tests)

**Files:**
- Modify: `desktop-pet-core/Sources/DPRenderer/RenderPass.swift`
- Modify: `desktop-pet-core/Sources/DPRenderer/Renderer.swift`
- Modify: `desktop-pet-core/Tests/DPRendererTests/RendererDeviceTests.swift`

This is the foundational signature change. spec-001's logic tests (headless `tick(dt:)` with `into: nil`) are unaffected; the device tests (which pass a command buffer) are updated to pass a render encoder.

- [ ] **Step 1: Change `RenderPass.encode` + `AnyRenderPass` to encoder-based**

In `desktop-pet-core/Sources/DPRenderer/RenderPass.swift`, change the protocol method and `AnyRenderPass`:

Protocol (replace the `func encode(into commandBuffer: MTLCommandBuffer, ...)` line):
```swift
    func encode(into encoder: MTLRenderCommandEncoder, context: Context) throws -> RenderPassId
```

`AnyRenderPass` (replace the `_encode` storage + `init` + `encode(into:)`):
```swift
    private let _encode: (MTLRenderCommandEncoder) throws -> RenderPassId

    public init<P: RenderPass>(_ pass: P, context: P.Context) {
        self.id = pass.id
        self.gpuLabel = pass.gpuLabel
        self._encode = { encoder in try pass.encode(into: encoder, context: context) }
    }

    public func encode(into encoder: MTLRenderCommandEncoder) throws -> RenderPassId {
        try _encode(encoder)
    }
```

- [ ] **Step 2: Change `Renderer.tick` to take an encoder; update `ClearPass`**

In `desktop-pet-core/Sources/DPRenderer/Renderer.swift`:

(a) Replace `Renderer.tick(dt:into:)`:
```swift
    public func tick(dt: Double, into encoder: MTLRenderCommandEncoder? = nil) {
        if !pendingRemovals.isEmpty {
            passes.removeAll { pendingRemovals.contains($0.id) }
            pendingRemovals.removeAll()
        }
        currentFrameIndex &+= 1
        isRunning = true
        for box in passes {
            if let enc = encoder {
                do { _ = try box.encode(into: enc) }
                catch { pendingDrops.insert(box.id) }
            }
            counterSink?(box.gpuLabel, 0)
        }
        if !pendingDrops.isEmpty {
            passes.removeAll { pendingDrops.contains($0.id) }
            pendingDrops.removeAll()
        }
    }
```

(b) In `ClearPass` (in `RenderPasses.swift`), change `encode(into: MTLCommandBuffer, ...)` → `encode(into encoder: MTLRenderCommandEncoder, context: Void) throws -> RenderPassId { id }`. (ClearPass stays a no-op; the actual clear is via the render-pass descriptor's `loadAction`.)

- [ ] **Step 3: Update spec-001 device tests to encoder-based**

In `desktop-pet-core/Tests/DPRendererTests/RendererDeviceTests.swift`, the three test passes (`RecordingPass`, `ThrowingPass`, `OKPass`, `NoopPass`) have `encode(into commandBuffer: MTLCommandBuffer, ...)`. Change each to `encode(into encoder: MTLRenderCommandEncoder, ...)` (bodies unchanged — they ignore the arg).

The tests call `r.tick(dt:, into: buffer)` with a command buffer. Replace each with an encoder. Add a helper at the top of the class:
```swift
    private func makeEncoder(device: MTLDevice, queue: MTLCommandQueue, size: (Int, Int) = (64, 64)) -> (MTLCommandBuffer, MTLRenderCommandEncoder) {
        let texDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: size.0, height: size.1, mipmapped: false)
        texDesc.usage = [.renderTarget]
        let tex = device.makeTexture(descriptor: texDesc)!
        let rpd = MTLRenderPassDescriptor()
        rpd.colorAttachments[0].texture = tex
        rpd.colorAttachments[0].loadAction = .dontCare
        rpd.colorAttachments[0].storeAction = .store
        let buffer = queue.makeCommandBuffer()!
        let enc = buffer.makeRenderCommandEncoder(descriptor: rpd)!
        return (buffer, enc)
    }
```
Then in each test, replace `let buffer = queue.makeCommandBuffer()!; r.tick(dt:, into: buffer); buffer.commit()` with:
```swift
        let (buffer, enc) = makeEncoder(device: device, queue: queue)
        r.tick(dt: 1.0 / 60.0, into: enc)
        enc.endEncoding()
        buffer.commit()
```
(For the two-frame `testThrowingPassDroppedAndLoopSurvives`, make two encoders/buffers.)

- [ ] **Step 4: Run full suite (all green — logic tests unaffected, device tests updated)**

Run: `swift test --package-path desktop-pet-core 2>&1 | tail -8`
Expected: 48 pass + 3 skip (the 3 device tests skip without `XPETS_GPU_TESTS`), 0 failures. (CI-skip still works.)

Run: `XPETS_GPU_TESTS=1 swift test --package-path desktop-pet-core --filter RendererDeviceTests 2>&1 | tail -8`
Expected: 3 device tests PASS (encoder-based, same behavior).

- [ ] **Step 5: Commit**

```bash
git add desktop-pet-core/Sources/DPRenderer/RenderPass.swift \
        desktop-pet-core/Sources/DPRenderer/Renderer.swift \
        desktop-pet-core/Tests/DPRendererTests/RendererDeviceTests.swift
git commit -m "impl(phase-2/spec-002b): RenderPass.encode → encoder-based

encode(into: MTLRenderCommandEncoder); Renderer.tick(dt:,into:encoder?).
Shell owns the encoder (view rpd + clear + present). spec-001 device
tests updated to make an encoder. Logic/headless tests unaffected.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Camera view + projection matrices

**Files:**
- Modify: `desktop-pet-core/Sources/DPRuntime/Scene.swift`
- Create: `desktop-pet-core/Tests/DPRuntimeTests/CameraTests.swift`

- [ ] **Step 1: Write the failing test**

Create `desktop-pet-core/Tests/DPRuntimeTests/CameraTests.swift`:
```swift
import XCTest
import simd
import DPRuntime
import DPFoundation

final class CameraTests: XCTestCase {
    func testViewMatrixMapsOriginToViewSpace() {
        let cam = Camera(position: SIMD3(0, 0, 5), target: SIMD3(0, 0, 0))
        let v = cam.viewMatrix() * SIMD4<Float>(0, 0, 0, 1)
        // Camera at z=5 looking at origin (down -Z): origin → view-z = -5.
        XCTAssertEqual(v.x, 0, accuracy: 1e-5)
        XCTAssertEqual(v.y, 0, accuracy: 1e-5)
        XCTAssertEqual(v.z, -5, accuracy: 1e-5)
        XCTAssertEqual(v.w, 1, accuracy: 1e-5)
    }

    func testProjectionMapsOriginToVisibleClipSpace() {
        let cam = Camera(position: SIMD3(0, 0, 5), target: SIMD3(0, 0, 0))
        let mvp = cam.projectionMatrix(aspect: 1) * cam.viewMatrix()
        let clip = mvp * SIMD4<Float>(0, 0, 0, 1)
        XCTAssertGreaterThan(clip.w, 0, "origin must be in front of the camera (w>0)")
        let ndcZ = clip.z / clip.w
        XCTAssertGreaterThanOrEqual(ndcZ, 0, "ndc z in [0,1]")
        XCTAssertLessThanOrEqual(ndcZ, 1, "ndc z in [0,1]")
    }
}
```
(`DPRuntimeTests` deps currently `["DPRuntime", "DPFoundation"]` — `Camera` is in DPRuntime (Scene.swift), so `import DPRuntime` suffices.)

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path desktop-pet-core --filter CameraTests 2>&1 | tail -15`
Expected: FAIL — `Camera` has no `viewMatrix()` / `projectionMatrix(aspect:)`.

- [ ] **Step 3: Add `import simd` to Scene.swift + extend Camera**

In `desktop-pet-core/Sources/DPRuntime/Scene.swift`, add `import simd` at the top (with the other imports). Then replace the `Camera` class with:
```swift
/// Camera — view + perspective projection. Phase 2b adds the matrices;
/// Phase 1 only stored position/target.
public final class Camera {
    public var position: Float3
    public var target: Float3
    public var fovY: Float
    public var nearZ: Float
    public var farZ: Float

    public init(position: Float3 = SIMD3(0, 0, 5), target: Float3 = SIMD3(0, 0, 0),
                fovY: Float = .pi / 4, nearZ: Float = 0.1, farZ: Float = 100) {
        self.position = position
        self.target = target
        self.fovY = fovY
        self.nearZ = nearZ
        self.farZ = farZ
    }

    public func viewMatrix() -> simd_float4x4 {
        let f = simd_normalize(target - position)           // forward (eye→target)
        let s = simd_normalize(simd_cross(f, SIMD3(0, 1, 0))) // right
        let u = simd_cross(s, f)                            // true up
        var m = simd_float4x4()
        m.columns.0 = SIMD4<Float>(s.x, u.x, -f.x, 0)
        m.columns.1 = SIMD4<Float>(s.y, u.y, -f.y, 0)
        m.columns.2 = SIMD4<Float>(s.z, u.z, -f.z, 0)
        m.columns.3 = SIMD4<Float>(-simd_dot(s, position), -simd_dot(u, position), simd_dot(f, position), 1)
        return m
    }

    public func projectionMatrix(aspect: Float) -> simd_float4x4 {
        let f = 1 / tan(fovY / 2)
        var m = simd_float4x4()
        m.columns.0 = SIMD4<Float>(f / aspect, 0, 0, 0)
        m.columns.1 = SIMD4<Float>(0, f, 0, 0)
        m.columns.2 = SIMD4<Float>(0, 0, farZ / (nearZ - farZ), -1)
        m.columns.3 = SIMD4<Float>(0, 0, (nearZ * farZ) / (nearZ - farZ), 0)
        return m
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path desktop-pet-core --filter CameraTests 2>&1 | tail -15`
Expected: PASS — 2 tests, 0 failures.

- [ ] **Step 5: Run full suite (no regression)**

Run: `swift test --package-path desktop-pet-core 2>&1 | tail -3`
Expected: 50 pass + 3 skip, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add desktop-pet-core/Sources/DPRuntime/Scene.swift \
        desktop-pet-core/Tests/DPRuntimeTests/CameraTests.swift
git commit -m "impl(phase-2/spec-002b): Camera view+projection matrices

lookAt (right-handed) + Metal perspective (NDC z∈[0,1]). Camera at
(0,0,5)→origin maps to view-z=-5; MVP maps origin into visible clip space.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Shader source (vertex + fragment, unlit textured)

**Files:**
- Create: `desktop-pet-core/Sources/DPRenderer/Shaders.swift`
- Create: `desktop-pet-core/Tests/DPRendererTests/ShaderSourceTests.swift`

- [ ] **Step 1: Write the failing test**

Create `desktop-pet-core/Tests/DPRendererTests/ShaderSourceTests.swift`:
```swift
import XCTest
import DPRenderer

final class ShaderSourceTests: XCTestCase {
    func testShaderSourceNonEmpty() {
        XCTAssertTrue(Shaders.vertexSource.contains("fox_vertex"), "vertex source must define fox_vertex")
        XCTAssertTrue(Shaders.fragmentSource.contains("fox_fragment"), "fragment source must define fox_fragment")
        XCTAssertTrue(Shaders.vertexSource.contains("mvp"), "vertex source must use the mvp uniform")
        XCTAssertTrue(Shaders.fragmentSource.contains("albedo"), "fragment source must sample albedo")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path desktop-pet-core --filter ShaderSourceTests 2>&1 | tail -15`
Expected: FAIL — `cannot find 'Shaders' in scope`.

- [ ] **Step 3: Create Shaders.swift**

Create `desktop-pet-core/Sources/DPRenderer/Shaders.swift`:
```swift
import Foundation

/// Metal shader source for spec-002b (unlit textured). Compiled at runtime via
/// `MTLDevice.makeLibrary(source:options:)` — no .metal files (SwiftPM doesn't
/// compile them; this keeps `swift test`/CI intact). 2c swaps the fragment for
/// PBR Cook-Torrance.
public enum Shaders {
    public static let vertexSource = """
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
    float2 texcoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texcoord;
};

struct Uniforms {
    float4x4 mvp;
};

vertex VertexOut fox_vertex(VertexIn in [[stage_in]],
                            constant Uniforms& uni [[buffer(2)]]) {
    VertexOut out;
    out.position = uni.mvp * float4(in.position, 1.0);
    // Flip V to compensate for CGContext's bottom-left origin (PNGDecoder).
    out.texcoord = float2(in.texcoord.x, 1.0 - in.texcoord.y);
    return out;
}
"""

    public static let fragmentSource = """
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texcoord;
};

fragment float4 fox_fragment(VertexOut in [[stage_in]],
                            texture2d<float> albedo [[texture(0)]],
                            sampler albedoSampler [[sampler(0)]]) {
    return albedo.sample(albedoSampler, in.texcoord);
}
"""
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path desktop-pet-core --filter ShaderSourceTests 2>&1 | tail -15`
Expected: PASS — 1 test, 0 failures.

- [ ] **Step 5: Run full suite (no regression)**

Run: `swift test --package-path desktop-pet-core 2>&1 | tail -3`
Expected: 51 pass + 3 skip, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add desktop-pet-core/Sources/DPRenderer/Shaders.swift \
        desktop-pet-core/Tests/DPRendererTests/ShaderSourceTests.swift
git commit -m "impl(phase-2/spec-002b): Metal shader source (unlit textured)

Vertex (MVP + UV passthrough + V flip for CGContext origin) + fragment
(albedo sample). Runtime-compiled string (no .metal). 2c → PBR fragment.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: MaterialPass + MaterialPassContext + pipeline factory

**Files:**
- Create: `desktop-pet-core/Sources/DPRenderer/MaterialPass.swift`
- Create: `desktop-pet-core/Tests/DPRendererTests/MaterialPassDeviceTests.swift`

- [ ] **Step 1: Write the failing device test**

Create `desktop-pet-core/Tests/DPRendererTests/MaterialPassDeviceTests.swift`:
```swift
import XCTest
import Metal
import simd
import DPRenderer

final class MaterialPassDeviceTests: XCTestCase {
    private func skipUnlessGPU() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["XPETS_GPU_TESTS"] != nil,
                          "GPU test — set XPETS_GPU_TESTS=1 locally (skipped on CI)")
    }

    /// Pipeline state builds (shaders compile, vertex descriptor valid).
    func testPipelineStateCreates() throws {
        try skipUnlessGPU()
        guard let device = MTLCreateSystemDefaultDevice() else { try XCTSkip("no device") }
        let pipe = MaterialPass.makePipelineState(device: device, colorPixelFormat: .bgra8Unorm)
        XCTAssertNotNil(pipe, "pipeline state must build from Shaders source")
    }

    /// MaterialPass.encode draws vertexCount primitives without crashing.
    func testEncodeDrawsWithoutCrash() throws {
        try skipUnlessGPU()
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else { try XCTSkip("no device") }
        // 3 dummy triangles (3 verts) of zeroed position/UV.
        let positions = [SIMD3<Float>](repeating: SIMD3(0,0,0), count: 3)
        let texcoords = [SIMD2<Float>](repeating: SIMD2(0,0), count: 3)
        let posBuf = positions.withUnsafeBufferPointer { device.makeBuffer(bytes: $0.baseAddress!, length: $0.count * 12, options: []) }!
        let uvBuf = texcoords.withUnsafeBufferPointer { device.makeBuffer(bytes: $0.baseAddress!, length: $0.count * 8, options: []) }!
        let uniformBuf = device.makeBuffer(length: MemoryLayout<simd_float4x4>.size, options: [])!
        // 1x1 albedo texture.
        let texDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 1, height: 1, mipmapped: false)
        texDesc.usage = .shaderRead
        let albedo = device.makeTexture(descriptor: texDesc)!
        albedo.replace(region: MTLRegionMake2D(0,0,1,1), mipmapLevel: 0, withBytes: [UInt8](repeating: 255, count: 4), bytesPerRow: 4)

        let pipe = MaterialPass.makePipelineState(device: device, colorPixelFormat: .bgra8Unorm)!
        let ctx = MaterialPassContext(vertexBuffer: posBuf, texcoordBuffer: uvBuf, uniformBuffer: uniformBuf, albedoTexture: albedo, pipelineState: pipe, vertexCount: 3)
        let pass = MaterialPass(ctx)

        // Encode into an offscreen encoder.
        let targetDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 8, height: 8, mipmapped: false)
        targetDesc.usage = .renderTarget
        let target = device.makeTexture(descriptor: targetDesc)!
        let rpd = MTLRenderPassDescriptor()
        rpd.colorAttachments[0].texture = target
        rpd.colorAttachments[0].loadAction = .dontCare
        rpd.colorAttachments[0].storeAction = .store
        let buffer = queue.makeCommandBuffer()!
        let enc = buffer.makeRenderCommandEncoder(descriptor: rpd)!
        _ = try pass.encode(into: enc)
        enc.endEncoding()
        buffer.commit()
        // No crash = pass.
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `XPETS_GPU_TESTS=1 swift test --package-path desktop-pet-core --filter MaterialPassDeviceTests 2>&1 | tail -15`
Expected: FAIL — `cannot find 'MaterialPass' / 'MaterialPassContext' / 'makePipelineState' in scope`.

- [ ] **Step 3: Create MaterialPass.swift**

Create `desktop-pet-core/Sources/DPRenderer/MaterialPass.swift`:
```swift
import Foundation
import Metal
import simd

/// Static resources for the fox draw (captured at registration). Per-frame MVP
/// lives in `uniformBuffer`, updated by FoxRenderModule each tick.
public struct MaterialPassContext {
    public let vertexBuffer: MTLBuffer         // positions, float3×vertexCount
    public let texcoordBuffer: MTLBuffer       // texcoords, float2×vertexCount
    public let uniformBuffer: MTLBuffer        // simd_float4x4 MVP (64 bytes)
    public let albedoTexture: MTLTexture
    public let pipelineState: MTLRenderPipelineState
    public let vertexCount: Int

    public init(vertexBuffer: MTLBuffer, texcoordBuffer: MTLBuffer, uniformBuffer: MTLBuffer,
                albedoTexture: MTLTexture, pipelineState: MTLRenderPipelineState, vertexCount: Int) {
        self.vertexBuffer = vertexBuffer
        self.texcoordBuffer = texcoordBuffer
        self.uniformBuffer = uniformBuffer
        self.albedoTexture = albedoTexture
        self.pipelineState = pipelineState
        self.vertexCount = vertexCount
    }
}

/// Draws the fox mesh with the albedo texture. Unlit, static bind-pose (spec-002b).
/// PBR + skinning land in 2c.
public final class MaterialPass: RenderPass {
    public typealias Context = Void
    public let id: RenderPassId = RenderPassId("material")
    public var gpuLabel: String { "pbr.material" }
    private let ctx: MaterialPassContext

    public init(_ ctx: MaterialPassContext) { self.ctx = ctx }

    public func encode(into encoder: MTLRenderCommandEncoder, context: Void) throws -> RenderPassId {
        encoder.setRenderPipelineState(ctx.pipelineState)
        encoder.setVertexBuffer(ctx.vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(ctx.texcoordBuffer, offset: 0, index: 1)
        encoder.setVertexBuffer(ctx.uniformBuffer, offset: 0, index: 2)
        encoder.setFragmentTexture(ctx.albedoTexture, index: 0)
        encoder.setFragmentSamplerState(MTLSamplerDescriptor().label, index: 0) // see note below
        // Non-indexed draw (fox.glb has no index buffer).
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: ctx.vertexCount)
        return id
    }

    /// Build the pipeline state from `Shaders` source + a 2-attribute vertex descriptor.
    public static func makePipelineState(device: MTLDevice, colorPixelFormat: MTLPixelFormat) -> MTLRenderPipelineState? {
        guard let library = try? device.makeLibrary(source: Shaders.vertexSource + "\n" + Shaders.fragmentSource, options: nil),
              let vertexFn = library.makeFunction(name: "fox_vertex"),
              let fragmentFn = library.makeFunction(name: "fox_fragment") else { return nil }

        let vd = MTLVertexDescriptor()
        vd.attributes[0].format = .float3
        vd.attributes[0].bufferIndex = 0
        vd.attributes[0].offset = 0
        vd.attributes[1].format = .float2
        vd.attributes[1].bufferIndex = 1
        vd.attributes[1].offset = 0
        vd.layouts[0].stride = MemoryLayout<SIMD3<Float>>.size
        vd.layouts[1].stride = MemoryLayout<SIMD2<Float>>.size

        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = vertexFn
        desc.fragmentFunction = fragmentFn
        desc.vertexDescriptor = vd
        desc.colorAttachments[0].pixelFormat = colorPixelFormat
        return try? device.makeRenderPipelineState(descriptor: desc)
    }
}
```

**Note on the sampler line:** `encoder.setFragmentSamplerState(MTLSamplerDescriptor().label, ...)` is wrong — replace that line with:
```swift
        let s = MTLSamplerDescriptor()
        s.minFilter = .linear
        s.magFilter = .linear
        s.mipFilter = .notMipmapped
        if let sampler = device.makeSamplerState(descriptor: s) {
            encoder.setFragmentSamplerState(sampler, index: 0)
        }
```
But `encode` doesn't have `device`. The sampler should be created once (at boot, in FoxRenderModule) and stored in `MaterialPassContext`. Add `let samplerState: MTLSamplerState?` to `MaterialPassContext`, set it at construction, and in `encode`:
```swift
        if let s = ctx.samplerState { encoder.setFragmentSamplerState(s, index: 0) }
```
So the final `MaterialPassContext` adds `public let samplerState: MTLSamplerState?` (last param), and `encode` uses `ctx.samplerState`. The test constructs `MaterialPassContext(...)` without sampler (nil) — `if let` skips it; Metal defaults to a null sampler (nearest) which still samples. The test passes. FoxRenderModule (Task 5) creates a real sampler and passes it.

**Use this corrected version** — in Step 3, the `MaterialPassContext` struct must include `public let samplerState: MTLSamplerState?` and its init; `encode` uses `if let s = ctx.samplerState { encoder.setFragmentSamplerState(s, index: 0) }` (no `device` reference). The test's `MaterialPassContext(...)` call adds `samplerState: nil` as the last arg.

- [ ] **Step 4: Run test to verify it passes (local M4)**

Run: `XPETS_GPU_TESTS=1 swift test --package-path desktop-pet-core --filter MaterialPassDeviceTests 2>&1 | tail -15`
Expected: PASS — 2 tests (pipeline creates; encode draws without crash).

- [ ] **Step 5: Verify CI-skip**

Run: `swift test --package-path desktop-pet-core --filter MaterialPassDeviceTests 2>&1 | tail -8`
Expected: 2 skipped, 0 failures.

- [ ] **Step 6: Run full suite (no regression)**

Run: `swift test --package-path desktop-pet-core 2>&1 | tail -3`
Expected: 51 pass + 5 skip (3 spec-001 + 2 MaterialPass device), 0 failures.

- [ ] **Step 7: Commit**

```bash
git add desktop-pet-core/Sources/DPRenderer/MaterialPass.swift \
        desktop-pet-core/Tests/DPRendererTests/MaterialPassDeviceTests.swift
git commit -m "impl(phase-2/spec-002b): MaterialPass + pipeline factory

MaterialPass (RenderPass) + MaterialPassContext (vertex/texcoord/uniform
buffers, albedo texture, pipeline state, sampler). makePipelineState
compiles Shaders at runtime + 2-attribute vertex descriptor. Non-indexed
drawPrimitives. Device tests: pipeline builds, encode draws without crash.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: FoxRenderModule (boot upload + tick MVP) + Application boot order

**Files:**
- Create: `desktop-pet-core/Sources/DPRuntime/FoxRenderModule.swift`
- Modify: `desktop-pet-core/Sources/DPRuntime/Application.swift`

- [ ] **Step 1: Write the failing device test**

Append to `desktop-pet-core/Tests/DPRendererTests/MaterialPassDeviceTests.swift`:
```swift
import DPRuntime
import DPAsset

final class FoxRenderModuleDeviceTests: XCTestCase {
    private func skipUnlessGPU() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["XPETS_GPU_TESTS"] != nil,
                          "GPU test — set XPETS_GPU_TESTS=1 locally (skipped on CI)")
    }

    func testFoxRenderModuleBootsAndRegistersPass() throws {
        try skipUnlessGPU()
        guard let device = MTLCreateSystemDefaultDevice() else { try XCTSkip("no device") }
        // Decode the fox fixture directly.
        let url = URL(fileURLWithPath: "/Users/zcy/Documents/Workspace/MyProjects/agents/xpets/desktop-pet-core/Tests/DPAssetTests/Fixtures/fox.glb")
        let glb = try GLBDecoder.decode(url: url)
        let scene = Scene(renderer: RendererMock(), profiler: Profiler.shared, camera: Camera())
        scene.assetRegistry.register(.glb(glb), key: AssetKey(hash: "fox"))
        let renderer = RendererMock()  // its passGraph is a headless Renderer
        // The module needs the device + scene + a passGraph. Boot it manually.
        let mod = FoxRenderModule(device: device, scene: scene, passGraph: renderer.passGraph)
        let ctx = RuntimeContext(config: .default, logger: .shared)
        try mod.moduleWillBoot(ctx)
        try mod.moduleDidBoot(ctx)
        // MaterialPass should now be registered.
        XCTAssertTrue(renderer.passGraph.registeredPassIDs.contains(RenderPassId("material")))
        // Tick once — must not crash (writes MVP into the uniform buffer).
        try mod.moduleWillTick(ctx, dt: 1.0/60)
        try mod.moduleDidTick(ctx, dt: 1.0/60)
    }
}
```
(This test file now needs `DPRuntime` + `DPAsset` deps. `DPRendererTests` currently deps `["DPRenderer","DPProfiler","DPFoundation"]`. Add `DPRuntime` (which transitively brings DPAsset) in Package.swift.)

- [ ] **Step 2: Add `DPRuntime` to `DPRendererTests` deps**

In `desktop-pet-core/Package.swift`, change `DPRendererTests` deps from `["DPRenderer", "DPProfiler", "DPFoundation"]` to `["DPRenderer", "DPProfiler", "DPFoundation", "DPRuntime"]`.

- [ ] **Step 3: Run test to verify it fails**

Run: `XPETS_GPU_TESTS=1 swift test --package-path desktop-pet-core --filter FoxRenderModuleDeviceTests 2>&1 | tail -15`
Expected: FAIL — `cannot find 'FoxRenderModule' in scope`.

- [ ] **Step 4: Create FoxRenderModule.swift**

Create `desktop-pet-core/Sources/DPRuntime/FoxRenderModule.swift`:
```swift
import Foundation
import Metal
import simd
import DPFoundation
import DPRenderer
import DPAsset

/// Uploads the fox mesh + albedo texture to Metal resources at boot, builds the
/// pipeline, and registers the MaterialPass. Each tick writes the camera MVP
/// into the uniform buffer. Static bind-pose, unlit (spec-002b).
final class FoxRenderModule: RuntimeModule {
    let name = "FoxRender"
    let dependencies: [String] = ["AssetPreload-fox.glb"]   // boot after the fox is loaded
    private let device: MTLDevice
    private let scene: Scene
    private let passGraph: DPRenderer.Renderer
    private var uniformBuffer: MTLBuffer?

    init(device: MTLDevice, scene: Scene, passGraph: DPRenderer.Renderer) {
        self.device = device
        self.scene = scene
        self.passGraph = passGraph
    }

    func moduleWillBoot(_ ctx: RuntimeContext) {}

    func moduleDidBoot(_ ctx: RuntimeContext) {
        guard let (_, glb) = scene.assetRegistry.glb.first else {
            ctx.logger.error("FoxRender: no GLB asset loaded")
            return
        }
        // Upload positions + texcoords.
        let positions = glb.mesh.positions
        let texcoords = glb.mesh.texcoords
        guard let posBuf = positions.withUnsafeBufferPointer({ device.makeBuffer(bytes: $0.baseAddress!, length: $0.count * MemoryLayout<SIMD3<Float>>.size, options: []) }),
              let uvBuf = texcoords.withUnsafeBufferPointer({ device.makeBuffer(bytes: $0.baseAddress!, length: $0.count * MemoryLayout<SIMD2<Float>>.size, options: []) }),
              let uniBuf = device.makeBuffer(length: MemoryLayout<simd_float4x4>.size, options: []) else {
            ctx.logger.error("FoxRender: MTLBuffer creation failed")
            return
        }
        self.uniformBuffer = uniBuf

        // Resolve albedo texture via Material.fromGlb → imageIndex → DecodedImage.
        guard let material = try? Material.fromGlb(glb, assetKey: "fox", materialIndex: 0),
              case .texture(let texRef) = material.albedo,
              texRef.imageIndex < glb.images.count else {
            ctx.logger.error("FoxRender: no albedo texture")
            return
        }
        let img = glb.images[texRef.imageIndex]
        let texDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: img.width, height: img.height, mipmapped: false)
        texDesc.usage = .shaderRead
        guard let albedo = device.makeTexture(descriptor: texDesc) else {
            ctx.logger.error("FoxRender: albedo MTLTexture creation failed")
            return
        }
        img.rgba.withUnsafeBytes { albedo.replace(region: MTLRegionMake2D(0,0,img.width,img.height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: img.width * 4) }

        // Sampler.
        let sampDesc = MTLSamplerDescriptor()
        sampDesc.minFilter = .linear; sampDesc.magFilter = .linear; sampDesc.mipFilter = .notMipmapped
        let sampler = device.makeSamplerState(descriptor: sampDesc)

        // Pipeline.
        guard let pipe = MaterialPass.makePipelineState(device: device, colorPixelFormat: .bgra8Unorm) else {
            ctx.logger.error("FoxRender: pipeline state creation failed")
            return
        }

        let ctx2 = MaterialPassContext(vertexBuffer: posBuf, texcoordBuffer: uvBuf, uniformBuffer: uniBuf,
                                       albedoTexture: albedo, pipelineState: pipe, vertexCount: positions.count,
                                       samplerState: sampler)
        try? passGraph.registerPass(MaterialPass(ctx2), context: ())
    }

    func moduleWillTick(_ ctx: RuntimeContext, dt: Double) {}

    func moduleDidTick(_ ctx: RuntimeContext, dt: Double) {
        guard let uniBuf = uniformBuffer else { return }
        let view = scene.renderer.hostView.bounds
        let aspect = view.width > 0 && view.height > 0 ? Float(view.width / view.height) : 1.0
        let mvp = scene.camera.projectionMatrix(aspect: aspect) * scene.camera.viewMatrix()
        let ptr = uniBuf.contents().bindMemory(to: simd_float4x4.self, capacity: 1)
        ptr.pointee = mvp
    }

    func moduleWillShutdown(_ ctx: RuntimeContext) {}
}
```
(`Scene.assetRegistry` is `private(set)` — readable. `scene.renderer.hostView` is `RendererSurface.hostView`. `MaterialPassContext(...samplerState:)` matches the Task-4 corrected struct.)

- [ ] **Step 5: Wire FoxRenderModule into Application.run (boot order: device before bootAll)**

In `desktop-pet-core/Sources/DPRuntime/Application.swift`, rework `run()`:

(a) Create the device BEFORE `bootAll`. The current `run()` order is: (1) eventLoop.prepare → (2) register modules + bootAll → (3) attach view + prepare(device) + counterSink → (4) updateLoop.start → (5) eventLoop.run. Reorder to: eventLoop.prepare → create device → attach view + prepare + counterSink → register modules (incl. FoxRenderModule) + bootAll → updateLoop.start → eventLoop.run.

Concretely, in `run()`, replace the body from after `bootTime = ...` / `let ctx = ...` through the end of step (5), with this order:
```swift
        // (1) Activation
        eventLoop.prepare()

        // (2) Create the Metal device BEFORE boot so FoxRenderModule can upload.
        let device = MTLCreateSystemDefaultDevice()

        // (3) Attach renderer view + prepare + wire counterSink.
        let scale = window.attach(rendererView: renderer.hostView)
        if let device {
            renderer.prepare(device: device, scaleFactor: scale)
        } else {
            logger.warn("no Metal device available — running with software fallback")
        }
        renderer.passGraph.counterSink = { name, value in
            Profiler.shared.record(DPProfiler.Counter(name: name, value: value))
        }

        // (4) Register modules + boot. FoxRender depends on AssetPreload (fox loaded first).
        do {
            try moduleManager.register(RenderMeshModule(passGraph: renderer.passGraph))
            try moduleManager.register(AssetPreloadModule(url: URL(fileURLWithPath: config.assets.foxGLBPath),
                                                          loader: assetLoader, scene: scene, application: self))
            if let device {
                try moduleManager.register(FoxRenderModule(device: device, scene: scene, passGraph: renderer.passGraph))
            }
            try moduleManager.bootAll(ctx: ctx)
        } catch {
            logger.error("boot failure: \(error)")
            return
        }

        // (5) Start the frame loop.
        updateLoop.start()
        didBoot = true
        logger.info("Application boot took \(Int((CFAbsoluteTimeGetCurrent() - bootTime) * 1000))ms")
        // ... (keep the existing info logs + installTerminateBridge + observer + eventLoop.run)
```
(Keep the existing `installTerminateBridge()`, the `NotificationCenter` observer, and `eventLoop.run()` at the end. The `bootTime`/`ctx` lines at the top of `run()` stay.)

- [ ] **Step 6: Run the device test to verify it passes (local M4)**

Run: `XPETS_GPU_TESTS=1 swift test --package-path desktop-pet-core --filter FoxRenderModuleDeviceTests 2>&1 | tail -15`
Expected: PASS — module boots, registers MaterialPass (`material` in registeredPassIDs), tick doesn't crash.

- [ ] **Step 7: Run full suite (no regression; headless tests unaffected by boot-order change)**

Run: `swift test --package-path desktop-pet-core 2>&1 | tail -5`
Expected: 51 pass + 6 skip (3 spec-001 + 2 MaterialPass + 1 FoxRender device), 0 failures. (DPRuntimeTests that boot Application — if any assert the OLD boot order, update them; check `grep -rn 'bootAll\|moduleDidBoot' Tests/DPRuntimeTests`. If a test asserts ordering `["RenderMesh","AssetPreload-fox.glb"]` and now FoxRender is appended, update the expected list to include "FoxRender".)

- [ ] **Step 8: Commit**

```bash
git add desktop-pet-core/Sources/DPRuntime/FoxRenderModule.swift \
        desktop-pet-core/Sources/DPRuntime/Application.swift \
        desktop-pet-core/Package.swift \
        desktop-pet-core/Tests/DPRendererTests/MaterialPassDeviceTests.swift
git commit -m "impl(phase-2/spec-002b): FoxRenderModule + boot order (device before bootAll)

Boot: upload positions/UVs→MTLBuffer, albedo DecodedImage→MTLTexture,
build pipeline+uniform+sampler, register MaterialPass. Tick: write camera
MVP into uniform buffer. Application.run reordered: device created before
bootAll so FoxRender can upload. DPRendererTests += DPRuntime dep.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Phase1Renderer.renderFrame rework (encoder + tick + present) — fox draws

**Files:**
- Modify: `desktop-pet-core/Sources/DPRenderer/Renderer.swift`

- [ ] **Step 1: Rework Phase1Renderer.renderFrame**

In `desktop-pet-core/Sources/DPRenderer/Renderer.swift`, replace the `Phase1Renderer.renderFrame(into view: MTKView, dt: Double)` body. The current body calls `passGraph.tick(dt: dt, into: nil)` then does its own clear-color encode/present. Replace the WHOLE method body with:
```swift
    public func renderFrame(into view: MTKView, dt: Double) {
        guard prepared else { return }
        guard let queue = commandQueue,
              let buffer = queue.makeCommandBuffer(),
              let rpd = view.currentRenderPassDescriptor else { return }
        rpd.colorAttachments[0].loadAction = .clear
        rpd.colorAttachments[0].clearColor = MTLClearColor(red: 0.20, green: 0.55, blue: 0.85, alpha: 1.0)
        // Drive the pass graph into a render encoder (MaterialPass draws the fox).
        passGraph.tick(dt: dt, into: nil)   // frameIndex + counters (headless-style)
        guard let encoder = buffer.makeRenderCommandEncoder(descriptor: rpd) else { return }
        passGraph.tick(dt: dt, into: encoder)   // encode passes (fox draw)
        encoder.endEncoding()
        if let drawable = view.currentDrawable {
            buffer.present(drawable)
        }
        buffer.addCompletedHandler { _ in }
        buffer.commit()
        frameCount += 1
    }
```
**Wait — this calls `passGraph.tick` twice (once into:nil, once into:encoder), which double-increments `currentFrameIndex` and double-counters.** That's wrong. Fix: call tick ONCE with the encoder. The frameIndex/counter increment happens inside tick. Remove the `into: nil` call:
```swift
    public func renderFrame(into view: MTKView, dt: Double) {
        guard prepared else { return }
        guard let queue = commandQueue,
              let buffer = queue.makeCommandBuffer(),
              let rpd = view.currentRenderPassDescriptor else { return }
        rpd.colorAttachments[0].loadAction = .clear
        rpd.colorAttachments[0].clearColor = MTLClearColor(red: 0.20, green: 0.55, blue: 0.85, alpha: 1.0)
        guard let encoder = buffer.makeRenderCommandEncoder(descriptor: rpd) else { return }
        passGraph.tick(dt: dt, into: encoder)   // frameIndex++ + counters + encode fox draw
        encoder.endEncoding()
        if let drawable = view.currentDrawable { buffer.present(drawable) }
        buffer.addCompletedHandler { _ in }
        buffer.commit()
        frameCount += 1
    }
```
**Use this single-tick version.** (The `into: encoder` path increments frameIndex + records counters + encodes passes. `ClearPass` is a no-op; the clear is via `rpd.loadAction = .clear`.)

- [ ] **Step 2: Build + run headless self-check (no crash, fox loads)**

Run: `DPT_HEADLESS=1 swift run --package-path desktop-pet-core desktop-pet 2>&1 | tail -8`
Expected: headless self-check passes (fox loaded, 24 bones, 83 animFrames). Headless mode uses the stub modules (NOT FoxRenderModule), so no Metal draw — but confirms no compile breakage.

- [ ] **Step 3: Run full suite (no regression)**

Run: `swift test --package-path desktop-pet-core 2>&1 | tail -3`
Expected: 51 pass + 6 skip, 0 failures.

- [ ] **Step 4: Visual baseline — run interactive, screenshot the fox (local M4)**

Run (interactive, backgrounded + screenshot + kill):
```
swift run --package-path /Users/zcy/Documents/Workspace/MyProjects/agents/xpets/desktop-pet-core desktop-pet > /tmp/xpets-2b.log 2>&1 &
sleep 7
screencapture -x /tmp/xpets-2b-fox.png
pkill -f 'desktop-pet'
```
Open `/tmp/xpets-2b-fox.png`. Expected: the 320×320 overlay now shows the **textured fox** (orange fox silhouette with texture), not a flat sea-blue block. If the fox is upside-down, toggle the V-flip line in `Shaders.swift` (`1.0 - in.texcoord.y` → `in.texcoord.y`) and re-run. If the fox is tiny/huge/off-screen, adjust `Camera.fovY`/`position` and re-run.

Record the result in `acceptance.md` (Task 7): "fox visible (textured)" + the screenshot path + any tuning applied.

- [ ] **Step 5: Commit**

```bash
git add desktop-pet-core/Sources/DPRenderer/Renderer.swift
git commit -m "impl(phase-2/spec-002b): Phase1Renderer.renderFrame draws the fox

renderFrame: view rpd (clear sea-blue) → makeRenderCommandEncoder →
passGraph.tick(dt:,into:encoder) (MaterialPass draws the fox) → present.
Single tick (frameIndex + counters + encode). Fox now visible on overlay.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: findings + acceptance evidence + final gate

**Files:**
- Modify: `specs/Phase-2-Rendering/findings.md`
- Modify: `specs/Phase-2-Rendering/acceptance.md`

- [ ] **Step 1: Append 2b reconciliations to findings.md**

In `specs/Phase-2-Rendering/findings.md`, add a `## spec-002b (vertex pipeline + basic render)` section (after the spec-002a section, before `## Acceptance evidence`):
```markdown
## spec-002b (vertex pipeline + basic render)

| Spec text / expectation | Code reality | Rationale |
|---|---|---|
| spec-002 `MaterialPass` encodes into a command buffer | `RenderPass.encode(into: MTLRenderCommandEncoder, ...)` — the shell (Phase1Renderer) owns the encoder (view rpd + clear + present); passes encode into it. spec-001's `encode(into: MTLCommandBuffer)` evolved. | Correct Metal pattern; spec-001's command-buffer form was an idealized stub. spec-001 device tests updated. |
| spec-002 `SkinnedMesh` renderable | fox.glb is NON-INDEXED (no `indices` key, 2a finding). `MaterialPass` uses `drawPrimitives` (not `drawIndexedPrimitives`). | 2a finding carried forward. |
| spec-002 PBR / lighting | 2b is UNLIT (no normals, no lighting). fox.glb has no NORMAL attribute. | Defer PBR + normal computation to 2c. |
| spec-002 GPU skinning | 2b renders bind-pose (static). `AnimationState.skinningPose` ignored. | Defer GPU skinning to 2c. |
| Application boot order (spec-003) | Device creation moved BEFORE `bootAll` (was after). | FoxRenderModule needs the device at `moduleDidBoot` to upload Metal resources. |
| Phase-1 `Camera` (position/target only) | 2b adds `viewMatrix()` (lookAt, right-handed) + `projectionMatrix(aspect:)` (Metal perspective, NDC z∈[0,1]) + fov/near/far. | Needed for the vertex shader MVP. |
| `Material.fromGlb` / `MaterialPass` cross-module | `MaterialPass` in DPRenderer (renderer-primitive handles); scene→Metal conversion in `FoxRenderModule` (DPRuntime). | DPRenderer is below DPAsset/DPRuntime — same cross-module pattern as `Material.fromGlb` (2a). |
| PNG decode Y origin | PNGDecoder's CGContext has bottom-left origin; vertex shader flips V (`1.0 - texcoord.y`). | Compensate for image-origin vs UV-origin; tunable per visual. |
```

- [ ] **Step 2: Record the visual baseline in acceptance.md**

In `specs/Phase-2-Rendering/acceptance.md`, in the `## Evidence (local visual baselines)` section, add rows:
```markdown
| spec-002b | (fox visible) | `swift run --package-path desktop-pet-core desktop-pet` (interactive) + `screencapture` | fox textured on overlay (screenshot /tmp/xpets-2b-fox.png) | local green |
```
(If tuning was applied in Task 6 Step 4 — e.g. V-flip toggled, fov adjusted — note the final values here.)

- [ ] **Step 3: Run lint + full suite (final gate)**

Run: `./scripts/phase2-spec-lint.sh && swift test --package-path desktop-pet-core 2>&1 | tail -5`
Expected: lint PASS; 51 pass + 6 skip, 0 failures. spec-002 stays `Status: Approved` (2b is a sub-round).

- [ ] **Step 4: Commit**

```bash
git add specs/Phase-2-Rendering/findings.md specs/Phase-2-Rendering/acceptance.md
git commit -m "docs(phase-2/spec-002b): findings + acceptance evidence (fox visible)

8 spec↔reality reconciliations (encode evolution, non-indexed draw, unlit,
no skinning, boot order, Camera matrices, cross-module, V-flip). Visual
baseline: fox textured on overlay.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review (run by plan author)

**1. Spec coverage (spec-002 §2 Deliverables → tasks):**
- `Material` value type → 2a (done). `MaterialPass` (concrete RenderPass) → Task 4. `fromGlb` → 2a. Texture-hash cache → 2a. PBR Cook-Torrance fragment + visual ΔE → **2c (deferred)**. api/material-api.md → 2c. 2b covers: vertex pipeline + unlit textured draw + fox-visible milestone (per decomposition).

**2. Placeholder scan:** No TBD/TODO. Task 4 Step 3 has a self-correction (sampler line) — the corrected version is the canonical one; the implementer uses the corrected `MaterialPassContext` (with `samplerState`) + `encode` (with `if let`). Task 6 Step 1 has a self-correction (single-tick, not double) — the single-tick version is canonical. Both corrections are explicit in the plan.

**3. Type consistency:** `RenderPass.encode(into: MTLRenderCommandEncoder, ...)` (Task 1) → used by `MaterialPass.encode` (Task 4) + `ClearPass` (Task 1). `Renderer.tick(dt:, into: MTLRenderCommandEncoder?)` (Task 1) → used by Phase1Renderer (Task 6) + device tests (Task 1) + FoxRender test (Task 5, via passGraph). `MaterialPassContext(...samplerState:)` (Task 4 corrected) → constructed in FoxRenderModule (Task 5) + test (Task 4, samplerState: nil). `MaterialPass.makePipelineState(device:colorPixelFormat:)` (Task 4) → used in FoxRenderModule (Task 5) + test (Task 4). `Camera.viewMatrix()/projectionMatrix(aspect:)` (Task 2) → used in FoxRenderModule.tick (Task 5) + CameraTests (Task 2). `Shaders.vertexSource/fragmentSource` (Task 3) → used in MaterialPass.makePipelineState (Task 4). `FoxRenderModule(device:scene:passGraph:)` (Task 5) → constructed in Application.run (Task 5) + test (Task 5). `RenderPassId("material")` (Task 4) → asserted in FoxRender test (Task 5). ✓

**4. Boot-order risk:** The Application.run reorder (device before bootAll) may affect DPRuntimeTests that assert boot ordering. Task 5 Step 7 calls this out — verify/update those tests. If `ModuleManagerTests` asserts `ordering() == ["RenderMesh","AssetPreload-fox.glb"]`, it now includes "FoxRender" — update the expected list.

**Out-of-scope noted:** PBR shader, IBL, GPU skinning, normal computation, api/material-api.md → 2c. spec-002 `Status` stays Approved through 2b.
