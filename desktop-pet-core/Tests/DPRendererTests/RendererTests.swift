import XCTest
import Metal
import DPRenderer

final class RendererInitTests: XCTestCase {
    func testRendererInitDefaults() {
        let r = Renderer(device: nil)
        XCTAssertEqual(r.currentFrameIndex, 0)
        XCTAssertFalse(r.isRunning)
        XCTAssertEqual(r.registeredPassIDs, [])
    }
}

/// Minimal test pass — Context = Void, encode is a no-op (headless tests do not
/// exercise encode; device tests in RendererDeviceTests do).
private final class TestPass: RenderPass {
    typealias Context = Void
    let id: RenderPassId
    var gpuLabel: String { "test.\(id.raw)" }
    init(_ raw: String) { self.id = RenderPassId(raw) }
    func encode(into commandBuffer: MTLCommandBuffer, context: Void) throws -> RenderPassId { id }
}

final class RendererRegistryTests: XCTestCase {
    func testRegisterOrderIsStable() throws {
        let r = Renderer(device: nil)
        try r.registerPass(TestPass("A"), context: ())
        try r.registerPass(TestPass("B"), context: ())
        try r.registerPass(TestPass("C"), context: ())
        try r.registerPass(TestPass("D"), context: ())
        XCTAssertEqual(r.registeredPassIDs, [RenderPassId("A"), RenderPassId("B"), RenderPassId("C"), RenderPassId("D")])
    }

    func testUnregisterMiddleKeepsOrder() throws {
        let r = Renderer(device: nil)
        try r.registerPass(TestPass("A"), context: ())
        try r.registerPass(TestPass("B"), context: ())
        try r.registerPass(TestPass("C"), context: ())
        try r.registerPass(TestPass("D"), context: ())
        r.unregisterPass(id: RenderPassId("B"))
        // Removal is deferred to next tick (released on next present tick).
        XCTAssertEqual(r.registeredPassIDs, [RenderPassId("A"), RenderPassId("B"), RenderPassId("C"), RenderPassId("D")])
        r.tick(dt: 1.0 / 60.0)
        XCTAssertEqual(r.registeredPassIDs, [RenderPassId("A"), RenderPassId("C"), RenderPassId("D")])
    }
}