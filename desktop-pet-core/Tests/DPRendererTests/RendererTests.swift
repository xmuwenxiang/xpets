import XCTest
import DPRenderer

final class RendererInitTests: XCTestCase {
    func testRendererInitDefaults() {
        let r = Renderer(device: nil)
        XCTAssertEqual(r.currentFrameIndex, 0)
        XCTAssertFalse(r.isRunning)
        XCTAssertEqual(r.registeredPassIDs, [])
    }
}