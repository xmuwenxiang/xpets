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