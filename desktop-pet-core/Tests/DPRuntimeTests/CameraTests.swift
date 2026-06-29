import XCTest
import simd
import DPRuntime
import DPFoundation

final class CameraTests: XCTestCase {
    func testViewMatrixMapsOriginToViewSpace() {
        let cam = Camera(position: SIMD3(0, 0, 5), target: SIMD3(0, 0, 0))
        let v = cam.viewMatrix() * SIMD4<Float>(0, 0, 0, 1)
        // Camera at z=5 looking at origin (down -Z): origin → view-z = -5.
        XCTAssertEqual(v.x, 0, accuracy: 1e-5)
        XCTAssertEqual(v.y, 0, accuracy: 1e-5)
        XCTAssertEqual(v.z, -5, accuracy: 1e-5)
        XCTAssertEqual(v.w, 1, accuracy: 1e-5)
    }

    func testProjectionMapsOriginToVisibleClipSpace() {
        let cam = Camera(position: SIMD3(0, 0, 5), target: SIMD3(0, 0, 0))
        let mvp = cam.projectionMatrix(aspect: 1) * cam.viewMatrix()
        let clip = mvp * SIMD4<Float>(0, 0, 0, 1)
        XCTAssertGreaterThan(clip.w, 0, "origin must be in front of the camera (w>0)")
        let ndcZ = clip.z / clip.w
        XCTAssertGreaterThanOrEqual(ndcZ, 0, "ndc z in [0,1]")
        XCTAssertLessThanOrEqual(ndcZ, 1, "ndc z in [0,1]")
    }
}