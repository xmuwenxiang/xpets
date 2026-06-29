import Metal

/// Stable identifier for a registered render pass. Hashable + Sendable so it can
/// be used as a Set element and cross the Renderer thread boundary.
public struct RenderPassId: Hashable, Sendable {
    public let raw: String
    public init(_ raw: String) { self.raw = raw }
    /// The root anchor — the first pass conceptually attaches here.
    public static let root = RenderPassId("root")
}

/// Type-erased RenderPass box. STUB — fully implemented in Task 3 (real
/// RenderPass protocol + context-capturing box). This stub lets Task 2's
/// init test compile (no pass storage exercised yet).
public final class AnyRenderPass: @unchecked Sendable {
    public let id: RenderPassId
    public let gpuLabel: String
    public init(_ id: RenderPassId = RenderPassId("stub"), gpuLabel: String = "stub") {
        self.id = id
        self.gpuLabel = gpuLabel
    }
    func encode(into commandBuffer: MTLCommandBuffer) throws -> RenderPassId { id }
}