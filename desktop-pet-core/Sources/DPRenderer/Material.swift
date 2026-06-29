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
