import Foundation
import DPFoundation
import simd

/// The set of asset kinds `Loader` can hand out. Phase 1 uses `.glb` and `.shader`;
/// `.ktx2` is recognized at the API boundary but doesn't decode textures yet.
public enum AssetType: String, Sendable, Hashable {
    case glb
    case ktx2
    case shader
}

/// Asset value-typed once decoded. Phase 1 only fills `.glb` and `.shader`; other
/// cases return `.unsupported` until later phases ship decoders.
public enum Asset: @unchecked Sendable {
    case glb(GLBAsset)
    case ktx2(KTX2Asset)
    case shader(ShaderAsset)
    case unsupported(AssetType)
}

/// Container for glTF (.glb) decoded content (Phase 1 subset).
public struct GLBAsset: @unchecked Sendable {
    public var mesh: SkinnedMesh
    public var skeleton: SkeletonData
    public var animations: [AnimationData]
    public var textures: [URL]   // textures may be deferred-decoded

    public init(mesh: SkinnedMesh, skeleton: SkeletonData, animations: [AnimationData], textures: [URL]) {
        self.mesh = mesh
        self.skeleton = skeleton
        self.animations = animations
        self.textures = textures
    }
}

/// Skeleton derived from a glTF skin. Node IDs map directly to joint indices.
public struct SkeletonData: @unchecked Sendable {
    public let bones: [BoneData]
    /// `parents[i]` is the parent index of `bones[i]`, or `-1` for roots.
    public let parents: [Int]
    public let restPose: [Float4x4]

    public init(bones: [BoneData], parents: [Int], restPose: [Float4x4]) {
        self.bones = bones
        self.parents = parents
        self.restPose = restPose
    }
}

/// One bone.
public struct BoneData: @unchecked Sendable {
    public let id: Int           // joint index inside the skin
    public let name: String
    public init(id: Int, name: String) {
        self.id = id
        self.name = name
    }
}

/// A mesh that is skinned to a skeleton — Phase 1 only carries vertex counts,
/// per-vertex joint indices and weights. Geometry buffers live in the renderer layer.
public struct SkinnedMesh: @unchecked Sendable {
    public var vertexCount: Int
    public var indexCount: Int
    public var jointIndices: [SIMD4<UInt16>]   // length == vertexCount
    public var jointWeights: [SIMD4<Float>]    // length == vertexCount

    public init(vertexCount: Int, indexCount: Int, jointIndices: [SIMD4<UInt16>], jointWeights: [SIMD4<Float>]) {
        self.vertexCount = vertexCount
        self.indexCount = indexCount
        self.jointIndices = jointIndices
        self.jointWeights = jointWeights
    }
}

/// Animation clip extracted from a glTF animation. Phase 1 only ships linear TRS
/// sampling — Catmull-Rom on rotations lands in DPAnimation.
public struct AnimationData: @unchecked Sendable {
    public let name: String
    public let duration: Double
    public let channels: [AnimationChannel]
    public let looping: Bool

    public init(name: String, duration: Double, channels: [AnimationChannel], looping: Bool) {
        self.name = name
        self.duration = duration
        self.channels = channels
        self.looping = looping
    }
}

public struct AnimationChannel: @unchecked Sendable {
    /// Animation property affected by a channel. The glTF 2.0 spec names them
    /// `translation | rotation | scale`, but real-world .glb authors sometimes emit
    /// `translate`. We accept both forms to keep the decoder robust.
    public enum Property: String, Sendable, CaseIterable {
        case translate
        case translate2 = "translation"
        case rotate
        case rotation
        case scale

        /// Normalize to internal verb form so downstream consumers can pattern-match.
        public func canonical() -> Canonical {
            switch self {
            case .translate, .translate2: return .translate
            case .rotate, .rotation:      return .rotate
            case .scale:                  return .scale
            }
        }

        public enum Canonical { case translate, rotate, scale }
    }

    public let boneIndex: Int
    public let property: Property
    public let keyframes: [Keyframe]

    public init(boneIndex: Int, property: Property, keyframes: [Keyframe]) {
        self.boneIndex = boneIndex
        self.property = property
        self.keyframes = keyframes
    }
}

public struct Keyframe: @unchecked Sendable {
    public let time: Double
    public let value: KeyframeValue
}

public enum KeyframeValue: @unchecked Sendable {
    case translate(SIMD3<Float>)
    case rotate(simd_quatf)
    case scale(SIMD3<Float>)
}

/// KTX2 stub returned on `AssetType.ktx2`. Phase 1 returns metadata only.
public struct KTX2Asset: @unchecked Sendable {
    public let width: Int
    public let height: Int
    public let mipCount: Int
    public let format: String

    public init(width: Int, height: Int, mipCount: Int, format: String) {
        self.width = width
        self.height = height
        self.mipCount = mipCount
        self.format = format
    }
}

/// A shader library (.metal) — Phase 1 only hashes contents; the MTLLibrary wrapper
/// is provided by DPRenderer later.
public struct ShaderAsset: @unchecked Sendable {
    public let sourceHash: String
    public let sourcePath: String

    public init(sourceHash: String, sourcePath: String) {
        self.sourceHash = sourceHash
        self.sourcePath = sourcePath
    }
}
