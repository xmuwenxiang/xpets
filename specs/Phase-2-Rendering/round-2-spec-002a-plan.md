# spec-002a (Asset Pipeline) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the data foundation for PBR rendering — extend GLBDecoder to parse renderable geometry (POSITION/TEXCOORD/indices) + materials + PNG images, and add the `DPRenderer.Material` value model + `fromGlb` + texture-hash cache. No Metal/GPU.

**Architecture:** DPAsset owns glTF parsing (geometry/materials/PNG-decode via ImageIO) and the `MaterialData`/`DecodedImage` data structs; DPRenderer owns the `Material` value type with renderer-primitive handles (no DPAsset types, avoiding the DPAsset→DPRenderer circular dep); `Material.fromGlb` is an `extension DPRenderer.Material` defined in DPAsset (sees both). `SkinnedMesh`/`GLBAsset` get additive fields with defaults so Phase-1 call sites/tests stay green.

**Tech Stack:** Swift 5.10 / SwiftPM / macOS ImageIO+CoreGraphics (PNG) / XCTest.

**Branch:** `phase-2/spec-002a-asset-pipeline` (from `main` at commit `bfce52e`).

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `desktop-pet-core/Sources/DPAsset/AssetTypes.swift` | modify | `SkinnedMesh` += positions/texcoords/indices (default `[]`); `GLBAsset` += `materials`/`images` (default `[]`); new `MaterialData` + `DecodedImage`. |
| `desktop-pet-core/Sources/DPAsset/GLBDecoder.swift` | modify | Parse POSITION/TEXCOORD_0/indices values + materials + samplers/textures/images (PNG). |
| `desktop-pet-core/Sources/DPAsset/PNGDecoder.swift` | new | ImageIO decode PNG `Data` → `DecodedImage`. |
| `desktop-pet-core/Sources/DPAsset/TextureHashCache.swift` | new | `(assetKey) → .hit/.miss` process cache. |
| `desktop-pet-core/Sources/DPAsset/Material+FromGlb.swift` | new | `extension DPRenderer.Material { fromGlb(...) }`. |
| `desktop-pet-core/Sources/DPRenderer/Material.swift` | new | `Material` + `ColorOrTexture`/`ScalarOrTexture`/`MaterialTexture`/`SamplerDesc`/`MaterialError`. |
| `desktop-pet-core/Tests/DPAssetTests/GLBDecoderTests.swift` | modify | fox.glb fixture: add geometry + material + image assertions. |
| `desktop-pet-core/Tests/DPAssetTests/MaterialTests.swift` | new | fromGlb / cache hit / missingChannel / equality. |
| `desktop-pet-core/Tests/DPRendererTests/MaterialModelTests.swift` | new | Material construction + equality. |
| `desktop-pet-core/Package.swift` | modify | Add `DPRenderer` to `DPAssetTests` deps. |
| `specs/Phase-2-Rendering/findings.md` | modify | Append 2a reconciliation log. |

---

## Task 1: Data structs (AssetTypes additive)

**Files:**
- Modify: `desktop-pet-core/Sources/DPAsset/AssetTypes.swift`

Pure scaffolding — additive fields with defaults so Phase-1 call sites/tests stay green. No new test (TDD red lands in Task 2).

- [ ] **Step 1: Ensure `import simd` at top of AssetTypes.swift**

Open `desktop-pet-core/Sources/DPAsset/AssetTypes.swift`. If the file does not already have `import simd`, add it after the existing `import Foundation` line. (The struct already uses `SIMD4<UInt16>` so simd is likely imported; verify.)

- [ ] **Step 2: Add `DecodedImage` and `MaterialData` structs**

Append (before the `ShaderAsset` struct or at end of file):
```swift
/// A decoded image (RGBA8). Phase 2a decodes GLB-embedded PNGs into this;
/// MTLTexture upload lands in 2b.
public struct DecodedImage: Sendable, Equatable {
    public let rgba: [UInt8]
    public let width: Int
    public let height: Int
    public init(rgba: [UInt8], width: Int, height: Int) {
        self.rgba = rgba; self.width = width; self.height = height
    }
}

/// glTF material data parsed by GLBDecoder (no Metal). albedo/normal/ao/emissive
/// are image indices into GLBAsset.images (optional — fox.glb has only albedo).
public struct MaterialData: Sendable, Equatable {
    public let name: String
    public let albedoImageIndex: Int?
    public let metallicFactor: Float
    public let roughnessFactor: Float
    public let normalImageIndex: Int?
    public let aoImageIndex: Int?
    public let emissiveImageIndex: Int?
    public init(name: String, albedoImageIndex: Int?, metallicFactor: Float, roughnessFactor: Float,
                normalImageIndex: Int? = nil, aoImageIndex: Int? = nil, emissiveImageIndex: Int? = nil) {
        self.name = name
        self.albedoImageIndex = albedoImageIndex
        self.metallicFactor = metallicFactor
        self.roughnessFactor = roughnessFactor
        self.normalImageIndex = normalImageIndex
        self.aoImageIndex = aoImageIndex
        self.emissiveImageIndex = emissiveImageIndex
    }
}
```

- [ ] **Step 3: Extend `SkinnedMesh` with positions/texcoords/indices (defaults)**

Replace the existing `SkinnedMesh` struct (currently `vertexCount / indexCount / jointIndices / jointWeights` + init) with:
```swift
public struct SkinnedMesh: @unchecked Sendable {
    public var vertexCount: Int
    public var indexCount: Int
    public var jointIndices: [SIMD4<UInt16>]   // length == vertexCount
    public var jointWeights: [SIMD4<Float>]    // length == vertexCount
    public var positions: [SIMD3<Float>] = []   // NEW (2a)
    public var texcoords: [SIMD2<Float>] = []   // NEW (2a)
    public var indices: [UInt32] = []           // NEW (2a)

    public init(vertexCount: Int, indexCount: Int, jointIndices: [SIMD4<UInt16>], jointWeights: [SIMD4<Float>],
                positions: [SIMD3<Float>] = [], texcoords: [SIMD2<Float>] = [], indices: [UInt32] = []) {
        self.vertexCount = vertexCount
        self.indexCount = indexCount
        self.jointIndices = jointIndices
        self.jointWeights = jointWeights
        self.positions = positions
        self.texcoords = texcoords
        self.indices = indices
    }
}
```

- [ ] **Step 4: Extend `GLBAsset` with materials/images (defaults)**

Replace the existing `GLBAsset` struct's stored properties + init to add `materials` and `images` with default `[]`:
```swift
public struct GLBAsset: @unchecked Sendable {
    public var mesh: SkinnedMesh
    public var skeleton: SkeletonData
    public var animations: [AnimationData]
    public var textures: [URL]               // textures may be deferred-decoded
    public var materials: [MaterialData] = [] // NEW (2a)
    public var images: [DecodedImage] = []    // NEW (2a, PNG-decoded)

    public init(mesh: SkinnedMesh, skeleton: SkeletonData, animations: [AnimationData], textures: [URL],
                materials: [MaterialData] = [], images: [DecodedImage] = []) {
        self.mesh = mesh
        self.skeleton = skeleton
        self.animations = animations
        self.textures = textures
        self.materials = materials
        self.images = images
    }
}
```
(The existing `GLBDecoder` return call `GLBAsset(mesh:, skeleton:, animations:, textures: [])` still compiles — new params default.)

- [ ] **Step 5: Build + existing tests green (defaults keep behavior)**

Run: `swift build --package-path desktop-pet-core 2>&1 | tail -3`
Expected: `Build complete!` (0 warnings, 0 errors).

Run: `swift test --package-path desktop-pet-core --filter GLBDecoderTests 2>&1 | tail -5`
Expected: PASS (existing fox fixture test still green — new fields default empty, untouched assertions).

- [ ] **Step 6: Commit**

```bash
git add desktop-pet-core/Sources/DPAsset/AssetTypes.swift
git commit -m "impl(phase-2/spec-002a): data structs — SkinnedMesh geometry + GLBAsset materials/images

Additive fields with defaults (Phase-1 back-compat): SkinnedMesh.positions/
texcoords/indices; GLBAsset.materials/images; new MaterialData + DecodedImage.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Geometry parsing (positions / texcoords / indices)

**Files:**
- Modify: `desktop-pet-core/Sources/DPAsset/GLBDecoder.swift`
- Modify: `desktop-pet-core/Tests/DPAssetTests/GLBDecoderTests.swift`

- [ ] **Step 1: Write the failing tests**

Append to `desktop-pet-core/Tests/DPAssetTests/GLBDecoderTests.swift` (inside the `GLBDecoderTests` class):
```swift
    func testDecodeFixture_parsesGeometry() throws {
        let asset = try GLBDecoder.decode(url: testFixtureURL())
        XCTAssertEqual(asset.mesh.positions.count, asset.mesh.vertexCount,
                       "positions count must equal vertexCount")
        XCTAssertEqual(asset.mesh.texcoords.count, asset.mesh.vertexCount,
                       "texcoords count must equal vertexCount")
        XCTAssertGreaterThan(asset.mesh.positions.count, 0, "positions must be non-empty")
        XCTAssertGreaterThan(asset.mesh.texcoords.count, 0, "texcoords must be non-empty")
        XCTAssertGreaterThan(asset.mesh.indices.count, 0, "indices must be non-empty")
        XCTAssertEqual(asset.mesh.indices.count, asset.mesh.indexCount,
                       "indices count must equal indexCount")
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path desktop-pet-core --filter GLBDecoderTests/testDecodeFixture_parsesGeometry 2>&1 | tail -15`
Expected: FAIL — `positions.count` is 0 (default), not `vertexCount`.

- [ ] **Step 3: Add geometry reader helpers to GLBDecoder**

In `desktop-pet-core/Sources/DPAsset/GLBDecoder.swift`, add these three `private static` helpers (after `readJointWeights`, before `buildKeyframes`):
```swift
    private static func readPositions(accessorIndex: Int, accessors: [[String: Any]], bufferViews: [[String: Any]], bin: Data, vertexCount: Int) throws -> [SIMD3<Float>] {
        guard accessorIndex < accessors.count,
              let bvIdx = accessors[accessorIndex]["bufferView"] as? Int else {
            return Array(repeating: SIMD3<Float>(0,0,0), count: vertexCount)
        }
        let bv = bufferViews[bvIdx]
        let offset = (bv["byteOffset"] as? Int) ?? 0
        var out: [SIMD3<Float>] = []
        var pos = offset
        for _ in 0..<vertexCount {
            if pos + 12 > bin.count { break }
            out.append(SIMD3<Float>(bin.loadF(at: pos), bin.loadF(at: pos+4), bin.loadF(at: pos+8)))
            pos += 12
        }
        return out
    }

    private static func readTexcoords(accessorIndex: Int, accessors: [[String: Any]], bufferViews: [[String: Any]], bin: Data, vertexCount: Int) throws -> [SIMD2<Float>] {
        guard accessorIndex < accessors.count,
              let bvIdx = accessors[accessorIndex]["bufferView"] as? Int else {
            return Array(repeating: SIMD2<Float>(0,0), count: vertexCount)
        }
        let bv = bufferViews[bvIdx]
        let offset = (bv["byteOffset"] as? Int) ?? 0
        var out: [SIMD2<Float>] = []
        var pos = offset
        for _ in 0..<vertexCount {
            if pos + 8 > bin.count { break }
            out.append(SIMD2<Float>(bin.loadF(at: pos), bin.loadF(at: pos+4)))
            pos += 8
        }
        return out
    }

    private static func readIndices(accessorIndex: Int, accessors: [[String: Any]], bufferViews: [[String: Any]], bin: Data) throws -> [UInt32] {
        guard accessorIndex < accessors.count else { return [] }
        let acc = accessors[accessorIndex]
        guard let bvIdx = acc["bufferView"] as? Int, bvIdx < bufferViews.count else { return [] }
        let bv = bufferViews[bvIdx]
        let offset = (bv["byteOffset"] as? Int) ?? 0
        let cnt = (acc["count"] as? Int) ?? 0
        let componentType = (acc["componentType"] as? Int) ?? 5123
        let stride = componentType == 5125 ? 4 : 2   // 5125=uint32, 5123=uint16
        var out: [UInt32] = []
        var pos = offset
        for _ in 0..<cnt {
            if pos + stride > bin.count { break }
            if componentType == 5125 { out.append(bin.loadU32(at: pos)) }
            else { out.append(UInt32(bin.loadU16(at: pos))) }
            pos += stride
        }
        return out
    }
```

- [ ] **Step 4: Wire the helpers into the mesh-parsing block**

In `GLBDecoder.parse(root:bin:)`, the mesh block currently sets `mesh.vertexCount` from POSITION count and reads JOINTS_0/WEIGHTS_0. After the JOINTS/WEIGHTS `if let` block (which ends around the original line `mesh.jointWeights = try readJointWeights(...)`) and before the close of the `if let meshEntry = meshes.first { ... }` block, add:
```swift
            if let positionIdx = attrs["POSITION"] as? Int, positionIdx < accessors.count {
                mesh.positions = try readPositions(accessorIndex: positionIdx, accessors: accessors, bufferViews: bufferViews, bin: bin, vertexCount: mesh.vertexCount)
            }
            if let uvIdx = attrs["TEXCOORD_0"] as? Int, uvIdx < accessors.count {
                mesh.texcoords = try readTexcoords(accessorIndex: uvIdx, accessors: accessors, bufferViews: bufferViews, bin: bin, vertexCount: mesh.vertexCount)
            }
            if let indicesAccIdx = prim["indices"] as? Int, indicesAccIdx < accessors.count {
                mesh.indices = try readIndices(accessorIndex: indicesAccIdx, accessors: accessors, bufferViews: bufferViews, bin: bin)
            }
```
(Place inside the `if let meshEntry = meshes.first { ... }` block, after the JOINTS/WEIGHTS reading. The earlier `positionIdx`/`indicesAcc` local bindings at the top of the block are separate; these new `if let`s use distinct binding names — `positionIdx` clashes? The earlier code uses `if let positionIdx = attrs["POSITION"] as? Int, positionIdx < accessors.count, let cnt = accessors[positionIdx]["count"] as? Int`. To avoid shadowing, name the new binding `posIdx` and `uvIdx` and `idxAcc`:
```swift
            if let posIdx = attrs["POSITION"] as? Int, posIdx < accessors.count {
                mesh.positions = try readPositions(accessorIndex: posIdx, accessors: accessors, bufferViews: bufferViews, bin: bin, vertexCount: mesh.vertexCount)
            }
            if let uvIdx = attrs["TEXCOORD_0"] as? Int, uvIdx < accessors.count {
                mesh.texcoords = try readTexcoords(accessorIndex: uvIdx, accessors: accessors, bufferViews: bufferViews, bin: bin, vertexCount: mesh.vertexCount)
            }
            if let idxAcc = prim["indices"] as? Int, idxAcc < accessors.count {
                mesh.indices = try readIndices(accessorIndex: idxAcc, accessors: accessors, bufferViews: bufferViews, bin: bin)
            }
```
Use these `posIdx`/`uvIdx`/`idxAcc` names to avoid shadowing the earlier `positionIdx`/`indicesAcc`.)

- [ ] **Step 5: Run test to verify it passes**

Run: `swift test --package-path desktop-pet-core --filter GLBDecoderTests/testDecodeFixture_parsesGeometry 2>&1 | tail -15`
Expected: PASS — positions/texcoords/indices counts match vertexCount/indexCount, non-empty.

- [ ] **Step 6: Run full suite (no regression)**

Run: `swift test --package-path desktop-pet-core 2>&1 | tail -5`
Expected: all green (Phase-1 + spec-001 + new geometry test). The 3 device tests skip.

- [ ] **Step 7: Commit**

```bash
git add desktop-pet-core/Sources/DPAsset/GLBDecoder.swift \
        desktop-pet-core/Tests/DPAssetTests/GLBDecoderTests.swift
git commit -m "impl(phase-2/spec-002a): parse POSITION/TEXCOORD/indices geometry

GLBDecoder.readPositions/readTexcoords/readIndices; wire into mesh block.
fox.glb positions/texcoords/indices non-empty, counts self-consistent.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: PNGDecoder + materials/images parsing

**Files:**
- Create: `desktop-pet-core/Sources/DPAsset/PNGDecoder.swift`
- Modify: `desktop-pet-core/Sources/DPAsset/GLBDecoder.swift`
- Modify: `desktop-pet-core/Tests/DPAssetTests/GLBDecoderTests.swift`

- [ ] **Step 1: Write the failing tests**

Append to `desktop-pet-core/Tests/DPAssetTests/GLBDecoderTests.swift`:
```swift
    func testDecodeFixture_parsesMaterialAndImage() throws {
        let asset = try GLBDecoder.decode(url: testFixtureURL())
        XCTAssertEqual(asset.materials.count, 1, "fox.glb has exactly one material")
        let m = asset.materials[0]
        XCTAssertEqual(m.name, "fox_material")
        XCTAssertEqual(m.albedoImageIndex, 0, "albedo baseColorTexture → image 0")
        XCTAssertEqual(m.metallicFactor, 0)
        XCTAssertEqual(m.roughnessFactor, 0.58, accuracy: 0.001)
        XCTAssertNil(m.normalImageIndex, "fox has no normal map")
        XCTAssertEqual(asset.images.count, 1, "fox.glb has one decoded image")
        XCTAssertGreaterThan(asset.images[0].rgba.count, 0, "PNG decoded to non-empty pixels")
        XCTAssertGreaterThan(asset.images[0].width, 0)
        XCTAssertGreaterThan(asset.images[0].height, 0)
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path desktop-pet-core --filter GLBDecoderTests/testDecodeFixture_parsesMaterialAndImage 2>&1 | tail -15`
Expected: FAIL — `materials.count` is 0 (default empty).

- [ ] **Step 3: Create PNGDecoder**

Create `desktop-pet-core/Sources/DPAsset/PNGDecoder.swift`:
```swift
import Foundation
import ImageIO
import CoreGraphics

/// Decodes a PNG (or JPEG, via ImageIO) `Data` into an RGBA8 `DecodedImage`.
/// macOS-only (Apple Silicon gate already enforced by the runtime). MTLTexture
/// upload is deferred to spec-002b.
public enum PNGDecoder {
    public static func decode(_ data: Data) -> DecodedImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let w = cgImage.width
        let h = cgImage.height
        guard w > 0, h > 0 else { return nil }
        let bytesPerRow = w * 4
        var rgba = [UInt8](repeating: 0, count: bytesPerRow * h)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &rgba, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: bytesPerRow, space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        return DecodedImage(rgba: rgba, width: w, height: h)
    }
}
```

- [ ] **Step 4: Parse materials + images in GLBDecoder**

In `desktop-pet-core/Sources/DPAsset/GLBDecoder.swift`, in `parse(root:bin:)`, the existing top-of-function bindings read `nodes/skins/meshes/accessors/bufferViews/anims`. Add three more after `let bufferViews = ...`:
```swift
        let materialsJSON = (root["materials"] as? [[String: Any]]) ?? []
        let texturesJSON = (root["textures"] as? [[String: Any]]) ?? []
        let imagesJSON = (root["images"] as? [[String: Any]]) ?? []
```

Then, just before the final `return GLBAsset(...)` at the end of `parse`, add the materials + images parsing:
```swift
        // -------- Materials + Images (2a) --------
        var materials: [MaterialData] = []
        for (i, m) in materialsJSON.enumerated() {
            let name = (m["name"] as? String) ?? "material_\(i)"
            let pbr = (m["pbrMetallicRoughness"] as? [String: Any]) ?? [:]
            let metallicFactor = Float((pbr["metallicFactor"] as? Double) ?? 0)
            let roughnessFactor = Float((pbr["roughnessFactor"] as? Double) ?? 1)
            var albedoImageIndex: Int? = nil
            if let bct = pbr["baseColorTexture"] as? [String: Any],
               let texIdx = bct["index"] as? Int,
               texIdx < texturesJSON.count {
                albedoImageIndex = texturesJSON[texIdx]["source"] as? Int
            }
            materials.append(MaterialData(name: name, albedoImageIndex: albedoImageIndex,
                                          metallicFactor: metallicFactor, roughnessFactor: roughnessFactor))
        }

        var images: [DecodedImage] = []
        for im in imagesJSON {
            guard let bvIdx = im["bufferView"] as? Int, bvIdx < bufferViews.count else { continue }
            let bv = bufferViews[bvIdx]
            let offset = (bv["byteOffset"] as? Int) ?? 0
            let length = (bv["byteLength"] as? Int) ?? 0
            let end = offset + length
            guard length > 0, end <= bin.count else { continue }
            let imgData = bin.subdata(in: offset..<end)
            if let decoded = PNGDecoder.decode(imgData) { images.append(decoded) }
        }
```

Then change the final return to pass them:
```swift
        return GLBAsset(mesh: mesh, skeleton: skeleton, animations: animations, textures: [],
                        materials: materials, images: images)
```

- [ ] **Step 5: Run test to verify it passes**

Run: `swift test --package-path desktop-pet-core --filter GLBDecoderTests/testDecodeFixture_parsesMaterialAndImage 2>&1 | tail -15`
Expected: PASS — material[0] `fox_material`, albedoImageIndex 0, metallic 0, roughness 0.58; images[0] non-empty.

- [ ] **Step 6: Run full suite (no regression)**

Run: `swift test --package-path desktop-pet-core 2>&1 | tail -5`
Expected: all green.

- [ ] **Step 7: Commit**

```bash
git add desktop-pet-core/Sources/DPAsset/PNGDecoder.swift \
        desktop-pet-core/Sources/DPAsset/GLBDecoder.swift \
        desktop-pet-core/Tests/DPAssetTests/GLBDecoderTests.swift
git commit -m "impl(phase-2/spec-002a): PNGDecoder + parse materials/images

PNGDecoder (ImageIO → RGBA8 DecodedImage); GLBDecoder parses
pbrMetallicRoughness + baseColorTexture→image index + decodes GLB-embedded
PNGs. fox material[0] = fox_material, albedo img 0, metallic 0, roughness 0.58.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Material value model (DPRenderer)

**Files:**
- Create: `desktop-pet-core/Sources/DPRenderer/Material.swift`
- Create: `desktop-pet-core/Tests/DPRendererTests/MaterialModelTests.swift`

- [ ] **Step 1: Write the failing test**

Create `desktop-pet-core/Tests/DPRendererTests/MaterialModelTests.swift`:
```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path desktop-pet-core --filter MaterialModelTests 2>&1 | tail -15`
Expected: FAIL — `cannot find 'Material' in scope` (DPRenderer has no Material type).

- [ ] **Step 3: Create the Material model**

Create `desktop-pet-core/Sources/DPRenderer/Material.swift`:
```swift
import Foundation
import simd

/// Renderer-side PBR material. Holds renderer-primitive handles ONLY (imageIndex
/// into GLBAsset.images + a sampler descriptor) — no DPAsset types, so DPRenderer
/// does not import DPAsset (avoids the DPAsset→DPRenderer circular dependency).
/// `fromGlb` is an extension defined in DPAsset (Material+FromGlb.swift).
public struct SamplerDesc: Sendable, Equatable {
    public var minFilter: Int
    public var magFilter: Int
    public var wrapS: Int
    public var wrapT: Int
    public init(minFilter: Int = 9729, magFilter: Int = 9729, wrapS: Int = 10497, wrapT: Int = 10497) {
        self.minFilter = minFilter; self.magFilter = magFilter
        self.wrapS = wrapS; self.wrapT = wrapT
    }
}

public struct MaterialTexture: Sendable, Equatable {
    public let imageIndex: Int
    public let sampler: SamplerDesc
    public init(imageIndex: Int, sampler: SamplerDesc = SamplerDesc()) {
        self.imageIndex = imageIndex; self.sampler = sampler
    }
}

public enum ColorOrTexture: Equatable, Sendable {
    case color(SIMD3<Float>)
    case texture(MaterialTexture)
}

public enum ScalarOrTexture: Equatable, Sendable {
    case scalar(Float)
    case texture(MaterialTexture)
}

public struct Material: Equatable, Sendable {
    public let albedo: ColorOrTexture
    public let metallic: ScalarOrTexture
    public let roughness: ScalarOrTexture
    public let normalMap: MaterialTexture?
    public let aoMap: MaterialTexture?
    public let emissive: MaterialTexture?

    public init(albedo: ColorOrTexture, metallic: ScalarOrTexture, roughness: ScalarOrTexture,
                normalMap: MaterialTexture? = nil, aoMap: MaterialTexture? = nil, emissive: MaterialTexture? = nil) {
        self.albedo = albedo
        self.metallic = metallic
        self.roughness = roughness
        self.normalMap = normalMap
        self.aoMap = aoMap
        self.emissive = emissive
    }
}

public enum MaterialError: Error, Equatable {
    case missingChannel(materialIndex: Int, channel: String)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path desktop-pet-core --filter MaterialModelTests 2>&1 | tail -15`
Expected: PASS — 2 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add desktop-pet-core/Sources/DPRenderer/Material.swift \
        desktop-pet-core/Tests/DPRendererTests/MaterialModelTests.swift
git commit -m "impl(phase-2/spec-002a): Material value model (DPRenderer)

Material + ColorOrTexture/ScalarOrTexture/MaterialTexture/SamplerDesc +
MaterialError. Renderer-primitive handles (no DPAsset types → no circular dep).
fromGlb extension lands in DPAsset (next task).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: TextureHashCache + Material.fromGlb extension

**Files:**
- Create: `desktop-pet-core/Sources/DPAsset/TextureHashCache.swift`
- Create: `desktop-pet-core/Sources/DPAsset/Material+FromGlb.swift`
- Modify: `desktop-pet-core/Package.swift` (add `DPRenderer` to `DPAssetTests` deps)
- Create: `desktop-pet-core/Tests/DPAssetTests/MaterialTests.swift`

- [ ] **Step 1: Add `DPRenderer` to `DPAssetTests` deps**

In `desktop-pet-core/Package.swift`, the `DPAssetTests` testTarget currently has `dependencies: ["DPAsset", "DPFoundation"]`. Change it to:
```swift
        .testTarget(
            name: "DPAssetTests",
            dependencies: ["DPAsset", "DPRenderer", "DPFoundation"],
            path: "Tests/DPAssetTests",
            resources: [
                .copy("Fixtures")
            ]
        ),
```

- [ ] **Step 2: Write the failing tests**

Create `desktop-pet-core/Tests/DPAssetTests/MaterialTests.swift`:
```swift
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
        XCTAssertEqual(a, b, "same input → equal Material")
        // Second call must have hit the cache for the albedo channel.
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
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `swift test --package-path desktop-pet-core --filter MaterialTests 2>&1 | tail -15`
Expected: FAIL — `fromGlb` does not exist on Material; `TextureHashCache` not found.

- [ ] **Step 4: Create TextureHashCache**

Create `desktop-pet-core/Sources/DPAsset/TextureHashCache.swift`:
```swift
import Foundation

public enum TextureCacheResult: Sendable, Equatable {
    case hit
    case miss
}

/// Process-level texture cache keyed on a composite assetKey (e.g.
/// "<assetHash>.<materialIndex>.<channel>"). Phase 2a records hit/miss for the
/// albedo channel at `Material.fromGlb` time; MTLTexture caching lands in 2b.
public final class TextureHashCache: @unchecked Sendable {
    public static let shared = TextureHashCache()
    private var store: Set<String> = []
    private let lock = NSLock()

    public init() {}

    public func lookup(assetKey: String) -> TextureCacheResult {
        lock.lock(); defer { lock.unlock() }
        return store.contains(assetKey) ? .hit : .miss
    }

    public func store(assetKey: String) {
        lock.lock(); defer { lock.unlock() }
        store.insert(assetKey)
    }

    public func reset() {
        lock.lock(); defer { lock.unlock() }
        store.removeAll()
    }
}
```

- [ ] **Step 5: Create Material+FromGlb extension (in DPAsset)**

Create `desktop-pet-core/Sources/DPAsset/Material+FromGlb.swift`:
```swift
import Foundation
import DPRenderer

/// `Material.fromGlb` is defined in DPAsset (not DPRenderer) because it needs
/// `GLBAsset`/`MaterialData` (DPAsset types) AND `DPRenderer.Material`. DPRenderer
/// sits below DPAsset in the dep graph and cannot import DPAsset, so the factory
/// lives here as a cross-module extension.
extension DPRenderer.Material {
    /// Build a render Material from a parsed GLBAsset's material slot.
    /// `assetKey` scopes the texture cache (drift: spec-002 omits this param).
    public static func fromGlb(_ asset: GLBAsset, assetKey: String, materialIndex: Int,
                                cache: TextureHashCache = .shared) throws -> DPRenderer.Material {
        guard materialIndex < asset.materials.count else {
            throw MaterialError.missingChannel(materialIndex: materialIndex, channel: "material")
        }
        let md = asset.materials[materialIndex]
        guard let albedoIdx = md.albedoImageIndex else {
            throw MaterialError.missingChannel(materialIndex: materialIndex, channel: "albedo")
        }
        // Record cache hit/miss for the albedo channel.
        let albedoKey = "\(assetKey).\(materialIndex).albedo"
        if cache.lookup(assetKey: albedoKey) == .miss {
            cache.store(assetKey: albedoKey)
        }
        let albedo = ColorOrTexture.texture(MaterialTexture(imageIndex: albedoIdx))
        return Material(albedo: albedo,
                        metallic: .scalar(md.metallicFactor),
                        roughness: .scalar(md.roughnessFactor))
    }
}
```
Note: `MaterialError`, `ColorOrTexture`, `MaterialTexture`, `Material` resolve via `import DPRenderer`; `GLBAsset`, `TextureHashCache` are in-module (DPAsset). `MaterialError` is `DPRenderer.MaterialError` — the `throw MaterialError.missingChannel(...)` resolves to DPRenderer.MaterialError via the import.

- [ ] **Step 6: Run tests to verify they pass**

Run: `swift test --package-path desktop-pet-core --filter MaterialTests 2>&1 | tail -15`
Expected: PASS — 3 tests, 0 failures (parse fox material 0; cache hit on second; missingChannel on bad index).

- [ ] **Step 7: Run full suite (no regression)**

Run: `swift test --package-path desktop-pet-core 2>&1 | tail -5`
Expected: all green (Phase-1 + spec-001 + 2a geometry/material-image/material-model/fromGlb tests; 3 device skip).

- [ ] **Step 8: Commit**

```bash
git add desktop-pet-core/Sources/DPAsset/TextureHashCache.swift \
        desktop-pet-core/Sources/DPAsset/Material+FromGlb.swift \
        desktop-pet-core/Package.swift \
        desktop-pet-core/Tests/DPAssetTests/MaterialTests.swift
git commit -m "impl(phase-2/spec-002a): TextureHashCache + Material.fromGlb

TextureHashCache (.hit/.miss process cache); Material.fromGlb as a DPAsset
extension on DPRenderer.Material (cross-module — avoids circular dep).
fox material 0 → albedo .texture(0), metallic 0, roughness 0.58; cache
.hit on second call; missingChannel on bad index. DPAssetTests += DPRenderer dep.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: findings.md + final gate

**Files:**
- Modify: `specs/Phase-2-Rendering/findings.md`

- [ ] **Step 1: Append 2a reconciliation log to findings.md**

In `specs/Phase-2-Rendering/findings.md`, after the existing `## spec-001` section's content (before `## Acceptance evidence` or at end of the spec-001 section), add a new `## spec-002a` section:
```markdown

## spec-002a (asset pipeline)

| Spec text / expectation | Code reality | Rationale |
|---|---|---|
| spec-002 `DecodedModel.materials[i]` | `GLBAsset.materials: [MaterialData]` (new field). Phase-1 GLBDecoder returned `textures: []` and parsed no materials. | Phase-1 asset pipeline was skeleton/animation-only; 2a completes material parsing. |
| spec-002 `Material.fromGlb(materialIndex:)` | `Material.fromGlb(_:assetKey:materialIndex:cache:)` — `assetKey` scopes the texture cache; defined as an `extension DPRenderer.Material` in DPAsset. | `DPRenderer` is below `DPAsset` in the dep graph (DPAsset→DPRenderer), so `DPRenderer` cannot import `GLBAsset`; the factory must live in DPAsset. `assetKey` added for cache scoping. |
| spec-002 Material channels (albedo/metallic/roughness/normal/ao/emissive) | normal/ao/emissive made OPTIONAL (`nil`); `missingChannel` fires only for required albedo/metallic/roughness. | fox.glb has only `baseColorTexture` + metallic/roughness factors — no normal/AO/emissive. |
| spec-002 acceptance `albedo (0.85,0.55,0.30) SRGB` (color) | fox.glb albedo is a `baseColorTexture` (texture), not a `baseColorFactor` color. `Material.albedo: ColorOrTexture` supports both; fox is `.texture`. | Asset-specific; the spec's color reference does not match fox.glb. |
| spec-002 `SkinnedMesh` renderable geometry | Phase-1 `SkinnedMesh` had only joints/weights. 2a adds `positions`/`texcoords`/`indices` (default `[]` for back-compat). | Phase-1 geometry parsing was stubbed; 2a completes it. |
| NORMAL attribute | fox.glb has no NORMAL accessor. 2a parses only present attributes. | Note for 2b: vertex shader must compute or default normals. |
| Phase-1 acceptance "decoder output unchanged" | 2a adds fields additively. fox fixture test gains NEW assertions; existing assertions untouched. | Regression-as-correction — Phase-1 decoder was intentionally minimal. |
```

- [ ] **Step 2: Run lint + full suite (final gate)**

Run: `./scripts/phase2-spec-lint.sh && swift test --package-path desktop-pet-core 2>&1 | tail -5`
Expected: lint PASS; full suite green (Phase-1 + spec-001 + 2a tests; 3 device skip). No `Status:` change to spec-002 (stays Approved — 2a is a sub-round; spec-002 transitions only after 2b+2c).

- [ ] **Step 3: Commit**

```bash
git add specs/Phase-2-Rendering/findings.md
git commit -m "docs(phase-2/spec-002a): findings — 7 spec↔reality reconciliations

materials field, fromGlb location/assetKey, optional channels, albedo
texture-not-color, SkinnedMesh geometry, NORMAL absence, Phase-1 fixture
additive assertions.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review (run by plan author)

**1. Spec coverage (spec-002 §2 Deliverables → tasks):**
- `Material` value type (albedo/metallic/roughness/normal/ao/emissive + SamplerDesc) → Task 4. ✓
- `Material.fromGlb(materialIndex:)` → Task 5 (with assetKey drift). ✓
- Texture-hash cache (DPAsset namespace) → Task 5 (TextureHashCache). ✓
- `MaterialPass` / PBR shader / visual screenshot diff → **out of scope (2b/2c)** — 2a is the data sub-round. ✓ (deferred per decomposition)
- `api/material-api.md` → deferred to 2c (with the PBR shader); 2a findings captures the data-model drift. Acceptable.
- Tests: fromGlb fox material 0 (Task 5), missingChannel (Task 5), cache hit (Task 5), value equality (Task 4). ✓ (visual ΔE → 2c)

**2. Placeholder scan:** No TBD/TODO. All steps contain real code or exact commands. The `foxFixtureURL()` absolute fallback path is machine-specific (matches the existing Phase-1 test's pattern) — not a placeholder.

**3. Type consistency:** `MaterialData.albedoImageIndex: Int?` (Task 1) → read in `fromGlb` (Task 5) as `md.albedoImageIndex`. ✓ `MaterialTexture(imageIndex:)` (Task 4) → used in `fromGlb` (Task 5). ✓ `TextureHashCache.lookup/store` (Task 5) → used in `fromGlb` + test. ✓ `DecodedImage(rgba:width:height:)` (Task 1) → produced by PNGDecoder (Task 3) + asserted in test. ✓ `SkinnedMesh.positions/texcoords/indices` (Task 1) → filled by readPositions/readTexcoords/readIndices (Task 2). ✓ `GLBAsset.materials/images` (Task 1) → filled in parse (Task 3). ✓

**Out-of-scope noted:** `MaterialPass`, PBR shader, MTLTexture upload, vertex pipeline, `api/material-api.md` → 2b/2c. spec-002 `Status` stays Approved through 2a.
