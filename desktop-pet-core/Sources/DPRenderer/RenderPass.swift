import Metal

/// Stable identifier for a registered render pass. Hashable + Sendable so it can
/// be used as a Set element and cross the Renderer thread boundary.
public struct RenderPassId: Hashable, Sendable {
    public let raw: String
    public init(_ raw: String) { self.raw = raw }
    /// The root anchor — the first pass conceptually attaches here.
    public static let root = RenderPassId("root")
}

/// A single render pass. `associatedtype Context` is the pass's own input type;
/// the Renderer stores heterogeneous passes via `AnyRenderPass` type-erasure
/// (context is captured at registration time).
public protocol RenderPass: AnyObject {
    associatedtype Context
    var id: RenderPassId { get }
    var gpuLabel: String { get }
    /// Encode into the given command buffer. Throwing here is caught by the
    /// Renderer: the pass is dropped after the frame and ticking continues
    /// (Loop-survives invariant, Phase-1 spec-003 §5).
    func encode(into commandBuffer: MTLCommandBuffer, context: Context) throws -> RenderPassId
}

/// Type-erased RenderPass. Holds the pass and its captured context; exposes a
/// non-generic `encode(into:)`.
public final class AnyRenderPass: @unchecked Sendable {
    public let id: RenderPassId
    public let gpuLabel: String
    private let _encode: (MTLCommandBuffer) throws -> RenderPassId

    public init<P: RenderPass>(_ pass: P, context: P.Context) {
        self.id = pass.id
        self.gpuLabel = pass.gpuLabel
        self._encode = { commandBuffer in try pass.encode(into: commandBuffer, context: context) }
    }

    public func encode(into commandBuffer: MTLCommandBuffer) throws -> RenderPassId {
        try _encode(commandBuffer)
    }
}