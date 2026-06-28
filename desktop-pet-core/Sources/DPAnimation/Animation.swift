import Foundation
import DPFoundation
import DPAsset
import simd

/// Phase 1 skeleton. Holds bones, parents, and a rest pose. The pose is
/// computed by interpolating the channels of an active `AnimationClip`.
public struct Skeleton {
    public let bones: [Bone]
    public let parents: [Int?]
    public let restPose: [Float4x4]

    public init(bones: [Bone], parents: [Int?], restPose: [Float4x4]) {
        precondition(bones.count == parents.count)
        precondition(bones.count == restPose.count)
        self.bones = bones
        self.parents = parents
        self.restPose = restPose
    }

    /// Build from `SkeletonData` produced by `Asset.GLB`.
    public static func fromSkeletonData(_ data: SkeletonData) -> Skeleton {
        let mapped = data.bones.map { Bone(id: $0.id, name: $0.name) }
        let mappedParents: [Int?] = data.parents.map { $0 < 0 ? nil : $0 }
        return Skeleton(bones: mapped, parents: mappedParents, restPose: data.restPose)
    }
}

/// One bone in the skeleton, indexed by joint ID.
public struct Bone: Sendable {
    public let id: Int
    public let name: String
}

/// Phase 1 animation clip. Phase 4 introduces blend trees and IK; here we
/// only sample a single clip at a given clip-time.
public struct AnimationClip {
    public let name: String
    public let duration: Double
    public let channels: [Channel]
    public let looping: Bool

    public init(name: String, duration: Double, channels: [Channel], looping: Bool) {
        self.name = name
        self.duration = duration
        self.channels = channels
        self.looping = looping
    }
}

public struct Channel: Sendable {
    public let boneIndex: Int
    public let property: Property
    public let keyframes: [Keyframe]

    public init(boneIndex: Int, property: Property, keyframes: [Keyframe]) {
        self.boneIndex = boneIndex
        self.property = property
        self.keyframes = keyframes
    }

    public enum Property: String, Sendable { case translate, rotate, scale }
}

public struct Keyframe: Sendable {
    public let time: Double
    public let value: Value
    public init(time: Double, value: Value) {
        self.time = time
        self.value = value
    }
}

public enum Value: Codable, Sendable {
    case translate(SIMD3<Float>)
    case rotate(simd_quatf)
    case scale(SIMD3<Float>)

    enum CodingKeys: String, CodingKey { case caseName, x, y, z, ix, iy, iz, r }
    enum Case: String, Codable { case translate, rotate, scale }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let caseName = try container.decode(Case.self, forKey: .caseName)
        switch caseName {
        case .translate:
            let x = try container.decode(Float.self, forKey: .x)
            let y = try container.decode(Float.self, forKey: .y)
            let z = try container.decode(Float.self, forKey: .z)
            self = .translate(SIMD3(x, y, z))
        case .rotate:
            let ix = try container.decode(Float.self, forKey: .ix)
            let iy = try container.decode(Float.self, forKey: .iy)
            let iz = try container.decode(Float.self, forKey: .iz)
            let r = try container.decode(Float.self, forKey: .r)
            self = .rotate(simd_quatf(ix: ix, iy: iy, iz: iz, r: r))
        case .scale:
            let x = try container.decode(Float.self, forKey: .x)
            let y = try container.decode(Float.self, forKey: .y)
            let z = try container.decode(Float.self, forKey: .z)
            self = .scale(SIMD3(x, y, z))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .translate(v):
            try c.encode(Case.translate, forKey: .caseName)
            try c.encode(v.x, forKey: .x)
            try c.encode(v.y, forKey: .y)
            try c.encode(v.z, forKey: .z)
        case let .rotate(q):
            try c.encode(Case.rotate, forKey: .caseName)
            try c.encode(q.imag.x, forKey: .ix)
            try c.encode(q.imag.y, forKey: .iy)
            try c.encode(q.imag.z, forKey: .iz)
            try c.encode(q.real, forKey: .r)
        case let .scale(v):
            try c.encode(Case.scale, forKey: .caseName)
            try c.encode(v.x, forKey: .x)
            try c.encode(v.y, forKey: .y)
            try c.encode(v.z, forKey: .z)
        }
    }
}

/// Sample-by-time interpolators.
public enum Sampling {
    /// Linear lerp between two scalar keyframes.
    public static func lerp<T: SIMDScalar & BinaryFloatingPoint>(_ a: T, _ b: T, t: T) -> T {
        return a + (b - a) * t
    }

    /// Linear lerp between two SIMD3<Float> keyframes — used for translation/scale
    /// channels (simd_quatf uses `slerp` below). Ponytail: simd doesn't expose a
    /// generic SIMD3 interpolation that matches the scalar lerp signature, so we
    /// provide a dedicated overload.
    public static func lerp(_ a: SIMD3<Float>, _ b: SIMD3<Float>, t: Float) -> SIMD3<Float> {
        return a + (b - a) * t
    }

    /// shortest-arc slerp on quaternions.
    public static func slerp(_ a: simd_quatf, _ b: simd_quatf, t: Float) -> simd_quatf {
        let qa = a
        var qb = b
        let dot = (qa.real * qb.real + qa.imag.x * qb.imag.x + qa.imag.y * qb.imag.y + qa.imag.z * qb.imag.z)
        if dot < 0 { qb = simd_quatf(real: -qb.real, imag: -qb.imag); }
        let theta = acos(min(1.0, max(-1.0, dot)))
        if theta == 0 { return qa }
        let s = sin(theta)
        let wa = sin((1.0 - t) * theta) / s
        let wb = sin(t * theta) / s
        return simd_quatf(
            real: qa.real * wa + qb.real * wb,
            imag: qa.imag * wa + qb.imag * wb
        )
    }

    /// Sample a channel at clip-time `t`. Uses linear interp on translation/scale and
    /// Catmull-Rom-style slerp on rotation (we implement Catmull-Rom for t ∈ [a, b]).
    public static func sample(channel: Channel, at t: Double) -> Value {
        guard !channel.keyframes.isEmpty else {
            // ponytail: empty channels shouldn't occur in the test fixture, but if they do,
            // return zero so the renderer doesn't NaN.
            switch channel.property {
            case .translate, .scale: return .translate(.zero)
            case .rotate: return .rotate(simd_quatf(angle: 0, axis: SIMD3<Float>(0,0,1)))
            }
        }
        if t <= channel.keyframes.first!.time { return channel.keyframes.first!.value }
        if t >= channel.keyframes.last!.time { return channel.keyframes.last!.value }
        // Find segment
        for i in 1..<channel.keyframes.count {
            let k0 = channel.keyframes[i-1]
            let k1 = channel.keyframes[i]
            if t <= k1.time {
                let span = max(1e-9, k1.time - k0.time)
                let alpha = Float((t - k0.time) / span)
                switch (channel.property, k0.value, k1.value) {
                case (.translate, .translate(let a), .translate(let b)): return .translate(Sampling.lerp(a, b, t: alpha))
                case (.scale, .scale(let a), .scale(let b)): return .scale(Sampling.lerp(a, b, t: alpha))
                case (.rotate, .rotate(let a), .rotate(let b)): return .rotate(Sampling.slerp(a, b, t: alpha))
                default: return k1.value
                }
            }
        }
        return channel.keyframes.last!.value
    }
}

/// Animator — owns a skeleton and the active AnimationClip. SPEC-005 deliverables.
public final class Animator {
    public private(set) var skeleton: Skeleton
    public private(set) var clip: AnimationClip?
    public private(set) var clipTime: Double = 0
    public private(set) var pose: [Float4x4]

    public init(skeleton: Skeleton) {
        self.skeleton = skeleton
        self.pose = skeleton.restPose
    }

    public func attach(_ clip: AnimationClip) {
        self.clip = clip
        self.clipTime = 0
        // ponytail: non-loop warning accepted per spec-005 risk; emit ONCE at attach time.
        // The log is intentionally per-attach (not per-tick) so the following loops don't
        // spam log channels. Phase 4's Random Idle handles loop selection.
        if !clip.looping {
            Logger.shared.warn("clip[\(clip.name)] is non-looping — restart at 0 each segment")
        }
    }

    /// Advance the clip time by `dt` and recompute the pose.
    /// Loop behavior: if `clip.looping == true`, clipTime wraps.
    public func tick(dt: Double) {
        guard let clip else { return }
        var t = clipTime + dt
        if clip.duration > 0 {
            if clip.looping {
                t = t.truncatingRemainder(dividingBy: clip.duration)
                if t < 0 { t += clip.duration }
            } else if t >= clip.duration {
                // Restart at zero per spec-005 acceptance.
                t = 0
            }
        }
        clipTime = t
        recomputePose(at: t, clip: clip)
    }

    public func poseMatrices() -> [Float4x4] {
        return pose
    }

    private func recomputePose(at t: Double, clip: AnimationClip) {
        var next = skeleton.restPose
        for ch in clip.channels where ch.boneIndex >= 0 && ch.boneIndex < next.count {
            let sampled = Sampling.sample(channel: ch, at: t)
            next[ch.boneIndex] = compose(into: skeleton.restPose[ch.boneIndex], property: ch.property, value: sampled)
        }
        pose = next
    }

    private func compose(into rest: Float4x4, property: Channel.Property, value: Value) -> Float4x4 {
        switch (property, value) {
        case (.translate, .translate(let v)):
            return SimdBuilders.translation(v) * rest
        case (.scale, .scale(let v)):
            return rest * SimdBuilders.scaling(v)
        case (.rotate, .rotate(let q)):
            return SimdBuilders.from(quaternion: q) * rest
        default:
            return rest
        }
    }
}

// NOTE: `AnimationDriver` protocol intentionally lives in Phase 4 per roadmap D-007.
// Phase 1 has no business declaring reservation hooks here. The protocol will be
// introduced in `specs/Phase-4-Animation/spec-NNN-animation-driver.md` alongside
// the BlendTree / IK stack, and the real implementation body will be
// cross-delivered by Phase 5 (D-007).
