import Foundation
import Metal
import simd
import DPFoundation
import DPRenderer
import DPAsset

/// Uploads the fox mesh + albedo texture to Metal resources at boot, builds the
/// pipeline, and registers the MaterialPass. Each tick writes the camera MVP
/// into the uniform buffer. Static bind-pose, unlit (spec-002b).
public final class FoxRenderModule: RuntimeModule {
    public let name = "FoxRender"
    public let dependencies: [String] = ["AssetPreload-fox.glb"]   // boot after the fox is loaded
    private let device: MTLDevice
    private let scene: Scene
    private let passGraph: DPRenderer.Renderer
    private var uniformBuffer: MTLBuffer?

    public init(device: MTLDevice, scene: Scene, passGraph: DPRenderer.Renderer) {
        self.device = device
        self.scene = scene
        self.passGraph = passGraph
    }

    public func moduleWillBoot(_ ctx: RuntimeContext) {}

    public func moduleDidBoot(_ ctx: RuntimeContext) {
        guard let (_, glb) = scene.assetRegistry.glb.first else {
            ctx.logger.error("FoxRender: no GLB asset loaded")
            return
        }
        let positions = glb.mesh.positions
        let texcoords = glb.mesh.texcoords
        guard !positions.isEmpty else { ctx.logger.error("FoxRender: no positions"); return }
        guard let posBuf = positions.withUnsafeBufferPointer({ device.makeBuffer(bytes: $0.baseAddress!, length: $0.count * MemoryLayout<SIMD3<Float>>.size, options: []) }),
              let uvBuf = texcoords.withUnsafeBufferPointer({ device.makeBuffer(bytes: $0.baseAddress!, length: $0.count * MemoryLayout<SIMD2<Float>>.size, options: []) }),
              let uniBuf = device.makeBuffer(length: MemoryLayout<simd_float4x4>.size, options: []) else {
            ctx.logger.error("FoxRender: MTLBuffer creation failed")
            return
        }
        self.uniformBuffer = uniBuf

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

        let sampDesc = MTLSamplerDescriptor()
        sampDesc.minFilter = .linear; sampDesc.magFilter = .linear; sampDesc.mipFilter = .notMipmapped
        let sampler = device.makeSamplerState(descriptor: sampDesc)

        guard let pipe = MaterialPass.makePipelineState(device: device, colorPixelFormat: .bgra8Unorm) else {
            ctx.logger.error("FoxRender: pipeline state creation failed")
            return
        }

        let ctx2 = MaterialPassContext(vertexBuffer: posBuf, texcoordBuffer: uvBuf, uniformBuffer: uniBuf,
                                       albedoTexture: albedo, pipelineState: pipe, vertexCount: positions.count,
                                       samplerState: sampler)
        try? passGraph.registerPass(MaterialPass(ctx2), context: ())
    }

    public func moduleWillTick(_ ctx: RuntimeContext, dt: Double) {}

    public func moduleDidTick(_ ctx: RuntimeContext, dt: Double) {
        guard let uniBuf = uniformBuffer else { return }
        let view = scene.renderer.hostView.bounds
        let aspect = view.width > 0 && view.height > 0 ? Float(view.width / view.height) : 1.0
        let mvp = scene.camera.projectionMatrix(aspect: aspect) * scene.camera.viewMatrix()
        let ptr = uniBuf.contents().bindMemory(to: simd_float4x4.self, capacity: 1)
        ptr.pointee = mvp
    }

    public func moduleWillShutdown(_ ctx: RuntimeContext) {}
}