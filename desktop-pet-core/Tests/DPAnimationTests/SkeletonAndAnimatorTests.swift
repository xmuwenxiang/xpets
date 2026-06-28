import XCTest
@testable import DPAnimation
@testable import DPAsset
import simd

final class SkeletonAndAnimatorTests: XCTestCase {
    /// Build a fake skeleton and animator with at least one channel; verify that
    /// `tick(0.1)` then `tick(0.2)` results in a non-zero evolution of the pose.
    func testAnimatorAdvancesPoseUnderSingleClip() {
        let bones = (0..<3).map { Bone(id: $0, name: "joint_\($0)") }
        let parents: [Int?] = [-1, 0, 1].map { $0 < 0 ? nil : $0 }
        let identity = matrix_identity_float4x4
        let rest = [identity, identity, identity]
        let skeleton = Skeleton(bones: bones, parents: parents, restPose: rest)
        let animator = Animator(skeleton: skeleton)
        let channel = Channel(
            boneIndex: 1,
            property: .rotate,
            keyframes: [
                Keyframe(time: 0, value: .rotate(simd_quatf(angle: 0, axis: SIMD3(0,1,0)))),
                Keyframe(time: 1, value: .rotate(simd_quatf(angle: Float.pi / 4, axis: SIMD3(0,1,0))))
            ]
        )
        animator.attach(AnimationClip(name: "test", duration: 1, channels: [channel], looping: true))
        let pose0 = animator.poseMatrices()
        animator.tick(dt: 0.5)
        let poseMid = animator.poseMatrices()
        animator.tick(dt: 0.5)
        let poseEnd = animator.poseMatrices()

        XCTAssertEqual(pose0.count, 3)
        XCTAssertEqual(poseMid.count, 3)
        // After advancing, bone 1's matrix must differ from rest.
        let midBone1 = poseMid[1]
        let identityCols = matrix_identity_float4x4.columns
        XCTAssertFalse(approxEqualColumn(midBone1.columns.0, identityCols.0))
    }

    func testSlerpShortestArc() {
        // Two quaternions separated by a 180° turn around the X axis (i.e. the
        // shortest-arc angle is 180°, a half-circle). At t = 0.5 the slerp lands
        // at the midpoint rotation (90°), so the resulting quaternion's real
        // component equals cos(90° / 2) = cos(π/4) = √2/2 ≈ 0.7071.
        let a = simd_quatf(angle: 0, axis: SIMD3(1,0,0))
        let b = simd_quatf(angle: Float.pi, axis: SIMD3(1,0,0))
        let mid = Sampling.slerp(a, b, t: 0.5)
        XCTAssertLessThan(abs(mid.real - cos(Float.pi / 4)), 1e-4,
                          "mid real must equal cos(π/4) for shortest-arc slerp at t=0.5 (180° / 2 = 90° → mid is 90° rotated → real=cos(45°))")
    }

    private func approxEqualColumn(_ a: SIMD4<Float>, _ b: SIMD4<Float>) -> Bool {
        let eps: Float = 1e-4
        return all(abs(a - b) .< eps)
    }
}
