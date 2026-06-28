import XCTest
@testable import DPWindow
import DPFoundation

final class WindowConfigTests: XCTestCase {
    /// Spec-002 §5: Window attaches transparent / borderless / always-on-top / click-through.
    /// In unit tests we cannot create an `NSWindow` (and shouldn't), so we cover the
    /// `Configuration` plumbing end-to-end.
    func testConfiguration_initializesFromConfig() {
        let cfg = WindowConfig(width: 200, height: 200, position: .topLeft, multiDisplayPolicy: .primaryOnly, clickThrough: true)
        let conf = Window.Configuration(from: cfg)
        XCTAssertEqual(conf.width, 200)
        XCTAssertEqual(conf.height, 200)
        if case .topLeft = conf.position { /* ok */ } else {
            XCTFail("topLeft expected")
        }
        XCTAssertEqual(conf.multiDisplayPolicy, .primaryOnly)
        XCTAssertTrue(conf.clickThrough)
    }

    func testMouseRegions_addAndRemove() {
        var regions = Window.MouseRegions()
        let r = CGRect(x: 0, y: 0, width: 50, height: 50)
        regions.addInteractive(rect: r)
        XCTAssertEqual(regions.interactiveRects.count, 1)
        regions.removeInteractive(rect: r)
        XCTAssertEqual(regions.interactiveRects.count, 0)
    }
}

final class WindowMockTests: XCTestCase {
    /// Spec-002 §5: A test injects a `NSScreen` mock returning `backingScaleFactor = 2.0`;
    /// the WindowMock simulates this by reading scaling from a Hemisphere enum.
    func testMock_attachReturnsScaleFactor() {
        let mock = WindowMock()
        let view = NSView()
        let scale = mock.attach(rendererView: view)
        XCTAssertEqual(scale, 2.0)
    }
}
