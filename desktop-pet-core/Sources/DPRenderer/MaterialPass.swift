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
    public let samplerState: MTLSamplerState?

    public init(vertexBuffer: MTLBuffer, texcoordBuffer: MTLBuffer, uniformBuffer: MTLBuffer,
                albedoTexture: MTLTexture, pipelineState: MTLRenderPipelineState,
                vertexCount: Int, samplerState: MTLSamplerState? = nil) {
        self.vertexBuffer = vertexBuffer
        self.texcoordBuffer = texcoordBuffer
        self.uniformBuffer = uniformBuffer
        self.albedoTexture = albedoTexture
        self.pipelineState = pipelineState
        self.vertexCount = vertexCount
        self.samplerState = samplerState
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
        if let s = ctx.samplerState { encoder.setFragmentSamplerState(s, index: 0) }
        // Non-indexed draw (fox.glb has no index buffer).
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: ctx.vertexCount)
        return id
    }

    /// Build the pipeline state from `Shaders` source + a 2-attribute vertex descriptor.
    public static func makePipelineState(device: MTLDevice, colorPixelFormat: MTLPixelFormat) -> MTLRenderPipelineState? {
        // Vertex and fragment sources each define their own `VertexOut`; compile
        // them as separate Metal libraries to avoid redefinition conflicts.
        guard let vertexLib = try? device.makeLibrary(source: Shaders.vertexSource, options: nil),
              let fragmentLib = try? device.makeLibrary(source: Shaders.fragmentSource, options: nil),
              let vertexFn = vertexLib.makeFunction(name: "fox_vertex"),
              let fragmentFn = fragmentLib.makeFunction(name: "fox_fragment") else { return nil }

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
    }}