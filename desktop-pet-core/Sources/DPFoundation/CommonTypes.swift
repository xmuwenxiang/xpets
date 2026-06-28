import Foundation
import simd

/// Common types used across modules. Kept in DPFoundation so every module can depend
/// on them transitively without forming cycles.
///
/// Phase 1 only needs `Transform` and `AssetKey`. Phase 2+ grows this file.

/// A right-handed, column-major 4×4 matrix — mirrors `simd_float4x4`.
public typealias Float4x4 = simd_float4x4
public typealias Float3 = SIMD3<Float>
public typealias Float4 = SIMD4<Float>

/// Convenience: identity matrix.
public let identityFloat4x4 = matrix_identity_float4x4

/// A translation/rotation/scale transform — the canonical transform domain used
/// across Scene/Animation/Renderer. Does NOT include a shear axis.
public struct Transform: Equatable, Sendable {
    public var translation: Float3
    public var rotation: simd_quatf
    public var scale: Float3

    public init(translation: Float3 = .zero, rotation: simd_quatf = simd_quatf(angle: 0, axis: SIMD3(0,0,1)), scale: Float3 = SIMD3(1,1,1)) {
        self.translation = translation
        self.rotation = rotation
        self.scale = scale
    }

    public static let identity = Transform()

    public var matrix: Float4x4 {
        let t = SimdBuilders.translation(translation)
        let r = SimdBuilders.from(quaternion: rotation)
        let s = SimdBuilders.scaling(scale)
        return t * r * s
    }
}

/// Stable identifier for a loaded Asset. Phase 1 uses the content-hash so the cache
/// can ignore file path. Phase 2 may add content-version for runtime validation.
public struct AssetKey: Hashable, Codable, Sendable, CustomStringConvertible {
    public let hash: String
    public init(hash: String) { self.hash = hash }

    public var description: String { "Asset(\(hash.prefix(8))…)" }
}

/// Common error surface for asset decoders — used uniformly by SPEC-004.
public enum AssetError: Error, Equatable {
    case ioError(underlying: String)
    case decodeError(reason: String)
    /// Mismatched GLTF / asset schema at a specific field. `expected` and `actual`
    /// capture the incompatibility for diagnostics; either may be nil when the
    /// loader only knows one side of the comparison (e.g., "field absent vs. required").
    case schemaMismatch(field: String, expected: String?, actual: String?)
    case unsupportedVersion(major: Int, minor: Int)
}

/// Common error surface for runtime lifecycle. Used by SPEC-003.
public enum LifecycleError: Error, Equatable {
    case bootTimeout
    case moduleNotFound(name: String)
    case moduleAlreadyRegistered(name: String)
    case dependencyMissing(dependency: String, owner: String)
    case shutdownInProgress
}
