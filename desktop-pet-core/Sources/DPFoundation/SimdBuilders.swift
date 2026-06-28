import Foundation
import simd

/// simd helpers — concrete matrix/vector constructors that don't rely on platform-specific
/// named initializers. Public so Animation and Asset layers can re-use them.
public enum SimdBuilders {
    public static func translation(_ v: Float3) -> Float4x4 {
        var m = matrix_identity_float4x4
        m.columns.3 = Float4(v.x, v.y, v.z, 1)
        return m
    }

    public static func scaling(_ v: Float3) -> Float4x4 {
        var m = matrix_identity_float4x4
        m.columns.0 = Float4(v.x, 0, 0, 0)
        m.columns.1 = Float4(0, v.y, 0, 0)
        m.columns.2 = Float4(0, 0, v.z, 0)
        return m
    }

    public static func from(quaternion q: simd_quatf) -> Float4x4 {
        let x = q.imag.x, y = q.imag.y, z = q.imag.z, w = q.real
        let rx = Float4(
            1 - 2 * (y*y + z*z), 2 * (x*y - z*w),     2 * (x*z + y*w),     0
        )
        let ry = Float4(
            2 * (x*y + z*w),     1 - 2 * (x*x + z*z), 2 * (y*z - x*w),     0
        )
        let rz = Float4(
            2 * (x*z - y*w),     2 * (y*z + x*w),     1 - 2 * (x*x + y*y), 0
        )
        return Float4x4(columns: (rx, ry, rz, Float4(0,0,0,1)))
    }
}
