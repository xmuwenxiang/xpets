import XCTest
import Metal
import simd
import DPFoundation
import DPRenderer
import DPRuntime
import DPAsset
import DPProfiler

final class MaterialPassDeviceTests: XCTestCase {
    private func skipUnlessGPU() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["XPETS_GPU_TESTS"] != nil,
                          "GPU test — set XPETS_GPU_TESTS=1 locally (skipped on CI)")
    }

    /// Pipeline state builds (shaders compile, vertex descriptor valid).
    func testPipelineStateCreates() throws {
        try skipUnlessGPU()
        guard let device = MTLCreateSystemDefaultDevice() else { try XCTSkip("no device"); return }
        let pipe = MaterialPass.makePipelineState(device: device, colorPixelFormat: .bgra8Unorm)
        XCTAssertNotNil(pipe, "pipeline state must build from Shaders source")
    }

    /// MaterialPass.encode draws vertexCount primitives without crashing.
    func testEncodeDrawsWithoutCrash() throws {
        try skipUnlessGPU()
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else { try XCTSkip("no device"); return }
        let positions = [SIMD3<Float>](repeating: SIMD3(0,0,0), count: 3)
        let texcoords = [SIMD2<Float>](repeating: SIMD2(0,0), count: 3)
        let posBuf = positions.withUnsafeBufferPointer { device.makeBuffer(bytes: $0.baseAddress!, length: $0.count * 12, options: []) }!
        let uvBuf = texcoords.withUnsafeBufferPointer { device.makeBuffer(bytes: $0.baseAddress!, length: $0.count * 8, options: []) }!
        let uniformBuf = device.makeBuffer(length: MemoryLayout<simd_float4x4>.size, options: [])!
        let texDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 1, height: 1, mipmapped: false)
        texDesc.usage = .shaderRead
        let albedo = device.makeTexture(descriptor: texDesc)!
        albedo.replace(region: MTLRegionMake2D(0,0,1,1), mipmapLevel: 0, withBytes: [UInt8](repeating: 255, count: 4), bytesPerRow: 4)

        let pipe = MaterialPass.makePipelineState(device: device, colorPixelFormat: .bgra8Unorm)!
        let ctx = MaterialPassContext(vertexBuffer: posBuf, texcoordBuffer: uvBuf, uniformBuffer: uniformBuf, albedoTexture: albedo, pipelineState: pipe, vertexCount: 3, samplerState: nil)
        let pass = MaterialPass(ctx)

        let targetDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 8, height: 8, mipmapped: false)
        targetDesc.usage = .renderTarget
        let target = device.makeTexture(descriptor: targetDesc)!
        let rpd = MTLRenderPassDescriptor()
        rpd.colorAttachments[0].texture = target
        rpd.colorAttachments[0].loadAction = .dontCare
        rpd.colorAttachments[0].storeAction = .store
        let buffer = queue.makeCommandBuffer()!
        let enc = buffer.makeRenderCommandEncoder(descriptor: rpd)!
        _ = try pass.encode(into: enc, context: ())
        enc.endEncoding()
        buffer.commit()
        // No crash = pass.
    }
}

final class FoxRenderModuleDeviceTests: XCTestCase {
    private func skipUnlessGPU() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["XPETS_GPU_TESTS"] != nil,
                          "GPU test — set XPETS_GPU_TESTS=1 locally (skipped on CI)")
    }

    func testFoxRenderModuleBootsAndRegistersPass() throws {
        try skipUnlessGPU()
        guard let device = MTLCreateSystemDefaultDevice() else { try XCTSkip("no device"); return }
        let url = URL(fileURLWithPath: "/Users/zcy/Documents/Workspace/MyProjects/agents/xpets/desktop-pet-core/Tests/DPAssetTests/Fixtures/fox.glb")
        let glb = try GLBDecoder.decode(url: url)
        let scene = Scene(renderer: RendererMock(), profiler: Profiler.shared, camera: Camera())
        scene.assetRegistry.register(.glb(glb), key: AssetKey(hash: "fox"))
        let renderer = RendererMock()
        let mod = FoxRenderModule(device: device, scene: scene, passGraph: renderer.passGraph)
        let ctx = RuntimeContext(config: DesktopPetConfig.default, logger: Logger.shared)
        try mod.moduleWillBoot(ctx)
        try mod.moduleDidBoot(ctx)
        XCTAssertTrue(renderer.passGraph.registeredPassIDs.contains(RenderPassId("material")))
        try mod.moduleWillTick(ctx, dt: 1.0/60)
        try mod.moduleDidTick(ctx, dt: 1.0/60)
    }
}