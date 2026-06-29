import Metal

/// The default root pass. In spec-001 its encode is a no-op (the on-screen clear
/// is still performed by Phase1Renderer's existing render path, preserving the
/// Phase-1 visual). spec-002+ replaces this with real PBR passes that do GPU
/// work into the view's command buffer.
public final class ClearPass: RenderPass {
    public typealias Context = Void
    public let id: RenderPassId = .root
    public var gpuLabel: String { "clear" }
    public init() {}
    public func encode(into encoder: MTLRenderCommandEncoder, context: Void) throws -> RenderPassId { id }
}