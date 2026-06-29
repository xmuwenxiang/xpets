# Phase 2 · Round 2a — spec-002 sub-round (Asset Pipeline) Design

> **Status**: Approved design (2026-06-29) — feeds `superpowers:writing-plans`.
> **Owner**: Xavier Zhang.
> **Parent spec**: [`spec-002-material-pbr.md`](spec-002-material-pbr.md) (`Status: Approved`; spec-002 stays Approved through 2a — it transitions Implementing→Done only after 2b+2c).
> **Decomposition**: "render the fox with PBR" is split 2a (asset/data, this doc) → 2b (vertex pipeline + basic render = fox visible) → 2c (PBR Cook-Torrance shader). See `execution-plan.md` §3.
> **Branch (planned)**: `phase-2/spec-002a-asset-pipeline`.

---

## 1. Goal

Build the data foundation for PBR rendering: extend the GLBDecoder to parse renderable geometry (POSITION / TEXCOORD_0 / indices) and materials (pbrMetallicRoughness + samplers + textures + PNG images); introduce the `DPRenderer.Material` value model + `fromGlb(_:)` + a texture-hash cache. **No Metal/GPU work** — purely the data layer, headless CI-testable. Rendering (MTLBuffer upload, vertex/fragment shaders, MaterialPass encoding) lands in 2b/2c.

## 2. Why this is a sub-round (scope finding)

spec-002 as written assumes `DecodedModel.materials[i]` and a renderable mesh exist. They do not — Phase 1's asset pipeline is a skeleton/animation-only stub:
- `SkinnedMesh` has only `vertexCount / indexCount / jointIndices / jointWeights` — **no positions, UVs, or indices**.
- `GLBDecoder` returns `GLBAsset(..., textures: [])` — **no materials, no textures parsed**; `SkinningPipeline` is CPU-only.

fox.glb reality (parsed for this design): 1 mesh (attributes `POSITION, TEXCOORD_0, JOINTS_0, WEIGHTS_0` — **no NORMAL**); 1 material `fox_material` (`pbrMetallicRoughness`: `baseColorTexture` + `metallicFactor=0` + `roughnessFactor=0.58` — **no normal/AO/emissive, albedo is a texture not a color**); 1 PNG image (bufferView 7).

So spec-002 needs three prerequisite chunks (geometry parse, material+texture parse, vertex pipeline) before its PBR shader ships. Decomposed: 2a = data (this round), 2b = vertex pipeline + basic render, 2c = PBR shader.

## 3. Architecture decision (locked)

**Extend `SkinnedMesh` additively (new fields default to empty arrays) + parse materials/textures/PNG into a `MaterialData` data model.**

- `SkinnedMesh` gains `positions: [SIMD3<Float>] = []`, `texcoords: [SIMD2<Float>] = []`, `indices: [UInt32] = []` — defaults keep the Phase-1 init compiling (call sites pass nothing → empty), 2a's GLBDecoder fills them.
- `GLBAsset` gains `materials: [MaterialData]` (new struct: albedo texture-ref + metallic/roughness factors + sampler; normal/ao/emissive optional refs).
- `DPRenderer.Material` is the renderer-side value model built FROM `MaterialData` via `Material.fromGlb(_:materialIndex:)` — keeps DPRenderer free of glTF parsing details (DPAsset owns parsing; DPRenderer owns the render material).
- PNG decode via macOS ImageIO (CGImageSource) → RGBA bytes + dims. MTLTexture upload deferred to 2b.

Chosen over a separate `MeshGeometry` struct (one mesh, two structs is awkward; SkinnedMesh IS the mesh).

## 4. Components / files

| File | Action | Responsibility |
|---|---|---|
| `desktop-pet-core/Sources/DPAsset/AssetTypes.swift` | modify | `SkinnedMesh` += positions/texcoords/indices (default empty); `GLBAsset` += `materials: [MaterialData]` + `images: [DecodedImage]`; new `MaterialData` / `DecodedImage` data structs (plain values, no Metal). |
| `desktop-pet-core/Sources/DPAsset/GLBDecoder.swift` | modify | Parse POSITION/TEXCOORD_0/indices accessors + primitive; parse `materials` (pbrMetallicRoughness, baseColorTexture index, metallicFactor, roughnessFactor) + samplers + textures + images. |
| `desktop-pet-core/Sources/DPAsset/PNGDecoder.swift` | new | ImageIO decode PNG bytes → `DecodedImage(rgba, width, height)`. macOS-only (Apple Silicon gate already enforced). |
| `desktop-pet-core/Sources/DPAsset/TextureHashCache.swift` | new | `(assetKey.hash, channel) → decoded pixels` cache; `.hit`/`.miss` lookup. |
| `desktop-pet-core/Sources/DPRenderer/Material.swift` | new | `Material` value type (renderer-primitive handles only — NO DPAsset types); `ColorOrTexture` / `ScalarOrTexture` / `MaterialTexture` / `SamplerDesc` (DPRenderer-internal, plain ints). |
| `desktop-pet-core/Sources/DPAsset/Material+FromGlb.swift` | new | `extension DPRenderer.Material { static func fromGlb(_ asset: GLBAsset, materialIndex: Int) throws -> Material }` — defined in DPAsset (sees GLBAsset; DPAsset already imports DPRenderer). |
| `desktop-pet-core/Tests/DPAssetTests/GLBDecoderTests.swift` | modify | fox.glb fixture: add assertions for positions/UV/indices non-empty + counts self-consistent + material parsed. |
| `desktop-pet-core/Tests/DPAssetTests/MaterialTests.swift` | new | fromGlb / cache hit / missingChannel / value equality (in DPAssetTests — has the fox.glb fixture + sees both DPAsset and DPRenderer). |
| `desktop-pet-core/Tests/DPAssetTests/PNGDecoderTests.swift` | new | fox.glb PNG image → non-empty pixels + sane dims. |
| `desktop-pet-core/Package.swift` | modify | Add `DPRenderer` to `DPAssetTests` deps (so MaterialTests can `import DPRenderer` for the `Material` type). `DPRendererTests` unchanged. |
| `specs/Phase-2-Rendering/findings.md` | modify | Append 2a reconciliation log (§6). |

## 5. Data model (sketch)

```swift
// DPAsset — parsed glTF data (no Metal)
public struct DecodedImage: Sendable, Equatable {
    public let rgba: [UInt8]
    public let width, height: Int
}
public struct MaterialData: Sendable, Equatable {
    public let name: String
    public let albedoImageIndex: Int?      // fox: 0 (baseColorTexture's image)
    public let metallicFactor: Float       // fox: 0
    public let roughnessFactor: Float      // fox: 0.58
    public let normalImageIndex: Int?      // optional (fox: nil)
    public let aoImageIndex: Int?          // optional (fox: nil)
    public let emissiveImageIndex: Int?    // optional (fox: nil)
}
// SkinnedMesh additions (default empty for Phase-1 back-compat)
public struct SkinnedMesh {
    public var vertexCount, indexCount: Int
    public var jointIndices: [SIMD4<UInt16>]
    public var jointWeights: [SIMD4<Float>]
    public var positions: [SIMD3<Float>] = []   // NEW
    public var texcoords: [SIMD2<Float>] = []   // NEW
    public var indices: [UInt32] = []           // NEW
}
// GLBAsset gains:
public struct GLBAsset {
    public var mesh: SkinnedMesh
    public var skeleton: SkeletonData
    public var animations: [AnimationData]
    public var textures: [URL]
    public var materials: [MaterialData] = []   // NEW
    public var images: [DecodedImage] = []      // NEW (PNG-decoded bytes)
}

// DPRenderer — render-side material (renderer-primitive handles ONLY;
// no DPAsset types, so DPRenderer does not import DPAsset — avoids the
// DPAsset→DPRenderer circular dependency).
public struct SamplerDesc: Sendable, Equatable {      // DPRenderer-internal
    public var minFilter, magFilter, wrapS, wrapT: Int
}
public struct MaterialTexture: Sendable, Equatable {  // handle into GLBAsset.images
    public let imageIndex: Int
    public let sampler: SamplerDesc
}
public enum ColorOrTexture: Equatable { case color(SIMD3<Float>); case texture(MaterialTexture) }
public enum ScalarOrTexture: Equatable { case scalar(Float); case texture(MaterialTexture) }
public struct Material: Equatable, Sendable {
    public let albedo: ColorOrTexture       // fox: .texture
    public let metallic: ScalarOrTexture    // fox: .scalar(0)
    public let roughness: ScalarOrTexture   // fox: .scalar(0.58)
    public let normalMap: MaterialTexture?  // nil for fox
    public let aoMap: MaterialTexture?
    public let emissive: MaterialTexture?
}
public enum MaterialError: Error, Equatable {
    case missingChannel(materialIndex: Int, channel: String)   // only for required albedo/metallic/roughness
}

// fromGlb is an extension on DPRenderer.Material DEFINED IN DPAsset
// (Sources/DPAsset/Material+FromGlb.swift), because DPAsset imports
// DPRenderer (sees Material) AND owns GLBAsset/MaterialData. The call
// `Material.fromGlb(asset, 0)` works in any module importing both.
extension DPRenderer.Material {
    public static func fromGlb(_ asset: GLBAsset, materialIndex: Int) throws -> Material
}
```

## 6. spec ↔ reality reconciliations (append to findings.md at round close)

1. **normal/AO/emissive optional**: spec-002 implies `missingChannel` for absent channels; fox.glb has none of these. Made `nil`-optional; `missingChannel` fires only for required albedo/metallic/roughness.
2. **albedo = ColorOrTexture**: fox.glb has `baseColorTexture` (texture), not a `baseColorFactor` color. spec-002 acceptance row's `albedo (0.85,0.55,0.30)` color reference does not match the asset — flagged as asset-specific; the enum supports both.
3. **NORMAL absent**: fox.glb has no NORMAL attribute. 2a parses only present attributes; 2b's vertex shader must compute/default normals (note for 2b).
4. **Phase-1 GLBDecoderTests updated**: 2a adds fields to decoded output (additive). Phase-1 acceptance row "decoder output unchanged" re-interpreted as "old fields unchanged, new fields additive"; fox.glb fixture test gains new assertions. This is a regression-as-correction.
5. **`Material.fromGlb` location**: spec-002 names `DPRenderer.Material.fromGlb`. But `DPRenderer` sits below `DPAsset` in the dep graph (DPAsset→DPRenderer), so `DPRenderer` cannot import `GLBAsset`. `Material` lives in DPRenderer (renderer-primitive handles, no DPAsset types); `fromGlb` is an `extension DPRenderer.Material` defined in **DPAsset** (`Material+FromGlb.swift`), which sees both. Honors the `Material.fromGlb(...)` call API; the definition site is the drift.

## 7. Testing (headless CI; no GPU)

- `Material.fromGlb(asset, 0)` → albedo `.texture`, metallic `.scalar(0)`, roughness `.scalar(0.58)`, normal/ao/emissive nil.
- Second `fromGlb` same key → texture-hash cache `.hit`, returns `==` Material.
- Missing required channel (synthetic fixture w/o metallic) → `MaterialError.missingChannel`.
- `Material` value equality: same input → `==`.
- PNGDecoder: fox.glb image → non-empty `rgba`, `width>0 && height>0`.
- GLBDecoder: fox.glb → `positions.count == vertexCount`, `texcoords.count == vertexCount`, `indices.count == indexCount`, `materials.count == 1`.

**Local M4 baseline**: none needed for 2a (no GPU/visual). Device tests are 2b.

## 8. Phase-1 / spec-001 regression

- Phase-1 30 tests + spec-001 8 logic tests + 3 device tests must stay green. `SkinnedMesh` new fields default-empty so existing Phase-1 GLBDecoderTests using the old init still compile/pass (they assert joints/weights only — unchanged). The fox fixture test gets ADDITIVE assertions (new fields non-empty) — existing assertions untouched.
- `phase2-spec-lint` unaffected (spec-002 stays Approved; no spec status changes in 2a).

## 9. Exit criteria (2a round close)

- All 2a logic tests CI green; full suite green (Phase-1 30 + spec-001 8 logic + 2a new; 3 device skip).
- No Phase-1/spec-001 regression.
- `findings.md` appended with §6 reconciliations.
- Geometry + material + PNG data now available in `GLBAsset` for 2b to upload to Metal.

## 10. Out of scope (deferred)

- MTLBuffer upload, vertex shader (MVP + skinning), fragment shader, MaterialPass encoding, MTLTexture creation → **2b**.
- PBR Cook-Torrance fragment, IBL → **2c / spec-003**.
- KTX2 / BasisU texture compression → Phase 8.
