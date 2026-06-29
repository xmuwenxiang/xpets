import XCTest
import Metal
import DPRenderer
import DPProfiler

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
    func encode(into encoder: MTLRenderCommandEncoder, context: Void) throws -> RenderPassId { id }
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

final class RendererDuplicateIDTests: XCTestCase {
    func testDuplicatePassIDThrowsAndPreservesOriginal() throws {
        let r = Renderer(device: nil)
        try r.registerPass(TestPass("A"), context: ())
        XCTAssertThrowsError(try r.registerPass(TestPass("A"), context: ())) { error in
            guard case .duplicatePassID(let id) = error as? RendererError else {
                XCTFail("expected duplicatePassID, got \(error)"); return
            }
            XCTAssertEqual(id, RenderPassId("A"))
        }
        // Original preserved exactly once.
        XCTAssertEqual(r.registeredPassIDs, [RenderPassId("A")])
    }
}

final class RendererAlreadyRunningTests: XCTestCase {
    func testRegisterAfterFirstTickThrowsAlreadyRunning() throws {
        let r = Renderer(device: nil)
        try r.registerPass(TestPass("A"), context: ())
        r.tick(dt: 1.0 / 60.0)   // first tick → isRunning = true
        XCTAssertThrowsError(try r.registerPass(TestPass("B"), context: ())) { error in
            guard case .alreadyRunning = error as? RendererError else {
                XCTFail("expected alreadyRunning, got \(error)"); return
            }
        }
        // B was NOT registered.
        XCTAssertEqual(r.registeredPassIDs, [RenderPassId("A")])
    }
}

final class RendererFrameIndexTests: XCTestCase {
    func testTickIncrementsFrameIndexAndSetsRunning() {
        let r = Renderer(device: nil)
        XCTAssertEqual(r.currentFrameIndex, 0)
        XCTAssertFalse(r.isRunning)
        r.tick(dt: 1.0 / 60.0)
        XCTAssertEqual(r.currentFrameIndex, 1)
        XCTAssertTrue(r.isRunning)
        r.tick(dt: 1.0 / 60.0)
        XCTAssertEqual(r.currentFrameIndex, 2)
        r.tick(dt: 1.0 / 60.0)
        XCTAssertEqual(r.currentFrameIndex, 3)
    }
}

final class RendererWeakReleaseTests: XCTestCase {
    func testUnregisterReleasesPassAfterDrain() throws {
        let r = Renderer(device: nil)
        weak var weakPass: TestPass?
        let id = RenderPassId("A")
        autoreleasepool {
            let pass = TestPass("A")
            weakPass = pass
            try? r.registerPass(pass, context: ())
        }
        // The AnyRenderPass box (closure capture) still holds the pass.
        XCTAssertNotNil(weakPass)
        r.unregisterPass(id: id)
        // Not yet drained.
        XCTAssertNotNil(weakPass)
        r.tick(dt: 1.0 / 60.0)  // drain
        XCTAssertNil(weakPass)
    }
}

final class RendererCounterSinkTests: XCTestCase {
    func testTickRecordsCounterPerPassViaSink() throws {
        let r = Renderer(device: nil)
        Profiler.shared.reset()
        defer { Profiler.shared.reset() }
        r.counterSink = { name, value in
            Profiler.shared.record(Counter(name: name, value: value))
        }
        try r.registerPass(TestPass("alpha"), context: ())
        try r.registerPass(TestPass("beta"), context: ())
        r.tick(dt: 1.0 / 60.0)
        XCTAssertNotNil(Profiler.shared.counters["test.alpha"])
        XCTAssertNotNil(Profiler.shared.counters["test.beta"])
    }
}