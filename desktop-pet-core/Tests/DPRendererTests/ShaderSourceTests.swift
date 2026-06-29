import XCTest
import DPRenderer

final class ShaderSourceTests: XCTestCase {
    func testShaderSourceNonEmpty() {
        XCTAssertTrue(Shaders.vertexSource.contains("fox_vertex"), "vertex source must define fox_vertex")
        XCTAssertTrue(Shaders.fragmentSource.contains("fox_fragment"), "fragment source must define fox_fragment")
        XCTAssertTrue(Shaders.vertexSource.contains("mvp"), "vertex source must use the mvp uniform")
        XCTAssertTrue(Shaders.fragmentSource.contains("albedo"), "fragment source must sample albedo")
    }
}
