import XCTest
@testable import DPAsset

final class GLBDecoderTests: XCTestCase {
    /// Spec-005 §5 enumerations: fox.glb integrity. Spec-004 requires decoder to handle
    /// the actual loader fixture.
    func testDecodeFixture_returnsNonEmptyGLB() throws {
        let url = testFixtureURL()
        let asset = try GLBDecoder.decode(url: url)
        XCTAssertGreaterThan(asset.skeleton.bones.count, 0,
                             "fox.glb must contain a non-empty skeleton")
        XCTAssertGreaterThan(asset.mesh.vertexCount, 0,
                             "fox.glb must contain mesh geometry")
    }

    func testDecodeCorruptData_throws() {
        var data = Data([0x67, 0x6C, 0x54, 0x46])        // magic
        data.append(contentsOf: [0,0,0,2])               // version 2
        data.append(contentsOf: [0,0,0,8])               // length
        data.append(contentsOf: [0,0,0,1])               // JSON chunk length = 1 (bad)
        XCTAssertThrowsError(try GLBDecoder.decode(data: data))
    }

    private func testFixtureURL() -> URL {
        // Bundle.module exposes the test target's resources directory if any.
        // Ponytail: the canonical fixture location is `Tests/DPAssetTests/Fixtures/fox.glb`,
        // included via `Package.swift` tests `resources: [.copy("Fixtures")]`. The
        // Bundle.module lookup should succeed in CI; the absolute-path fallback is a
        // safety net for local `swift test` runs that may not honor resources.
        let bundle = Bundle.module
        if let url = bundle.url(forResource: "Fixtures/fox", withExtension: "glb") {
            return url
        }
        // Fallback path is per-developer — never fail silently. The test will report
        // the missing-file error as part of its first assertion failure so a missing
        // fixture is surfaceable in CI logs.
        let path = "/Users/zcy/Documents/Workspace/MyProjects/agents/xpets/desktop-pet-core/Tests/DPAssetTests/Fixtures/fox.glb"
        return URL(fileURLWithPath: path)
    }
}
