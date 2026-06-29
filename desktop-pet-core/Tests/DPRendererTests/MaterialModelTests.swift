import XCTest
import simd
import DPRenderer

final class MaterialModelTests: XCTestCase {
    func testMaterialConstructionAndEquality() {
        let tex = MaterialTexture(imageIndex: 0)
        let a = Material(albedo: .texture(tex), metallic: .scalar(0), roughness: .scalar(0.58))
        let b = Material(albedo: .texture(tex), metallic: .scalar(0), roughness: .scalar(0.58))
        XCTAssertEqual(a, b)
        let c = Material(albedo: .color(SIMD3<Float>(1,0,0)), metallic: .scalar(1), roughness: .scalar(0.5))
        XCTAssertNotEqual(a, c)
    }

    func testMaterialTextureDefaults() {
        let tex = MaterialTexture(imageIndex: 3)
        XCTAssertEqual(tex.imageIndex, 3)
        XCTAssertEqual(tex.sampler, SamplerDesc())
    }
}
