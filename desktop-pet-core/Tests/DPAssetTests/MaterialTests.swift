import XCTest
@testable import DPAsset
import DPRenderer

final class MaterialTests: XCTestCase {
    private func foxAsset() throws -> GLBAsset {
        try GLBDecoder.decode(url: foxFixtureURL())
    }
    private func foxFixtureURL() -> URL {
        let bundle = Bundle.module
        if let url = bundle.url(forResource: "Fixtures/fox", withExtension: "glb") { return url }
        return URL(fileURLWithPath: "/Users/zcy/Documents/Workspace/MyProjects/agents/xpets/desktop-pet-core/Tests/DPAssetTests/Fixtures/fox.glb")
    }

    func testFromGlb_parsesFoxMaterial0() throws {
        TextureHashCache.shared.reset()
        let asset = try foxAsset()
        let m = try Material.fromGlb(asset, assetKey: "fox-test", materialIndex: 0)
        guard case .texture(let tex) = m.albedo else {
            XCTFail("expected .texture albedo, got \(m.albedo)"); return
        }
        XCTAssertEqual(tex.imageIndex, 0)
        guard case .scalar(let metallic) = m.metallic else { XCTFail("metallic"); return }
        XCTAssertEqual(metallic, 0)
        guard case .scalar(let rough) = m.roughness else { XCTFail("roughness"); return }
        XCTAssertEqual(rough, 0.58, accuracy: 0.001)
        XCTAssertNil(m.normalMap)
    }

    func testFromGlb_cacheHitOnSecondCall() throws {
        TextureHashCache.shared.reset()
        let asset = try foxAsset()
        let a = try Material.fromGlb(asset, assetKey: "fox-cache", materialIndex: 0)
        let b = try Material.fromGlb(asset, assetKey: "fox-cache", materialIndex: 0)
        XCTAssertEqual(a, b, "same input -> equal Material")
        let lookup = TextureHashCache.shared.lookup(assetKey: "fox-cache.0.albedo")
        XCTAssertEqual(lookup, .hit)
    }

    func testFromGlb_missingMaterialThrows() throws {
        TextureHashCache.shared.reset()
        let asset = try foxAsset()
        XCTAssertThrowsError(try Material.fromGlb(asset, assetKey: "fox-x", materialIndex: 99)) { error in
            guard case .missingChannel(let idx, _) = error as? MaterialError else {
                XCTFail("expected missingChannel, got \(error)"); return
            }
            XCTAssertEqual(idx, 99)
        }
    }
}