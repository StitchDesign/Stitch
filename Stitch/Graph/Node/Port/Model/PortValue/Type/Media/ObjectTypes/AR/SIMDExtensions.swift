import Foundation
import StitchSchemaKit
import simd

extension SIMD4 {
    var xyz: SIMD3<Scalar> {
        return SIMD3(x, y, z)
    }
}

extension simd_float4x4 {
    var upperLeft3x3: simd_float3x3 {
        return simd_float3x3(columns.0.xyz, columns.1.xyz, columns.2.xyz)
    }
}

extension simd_float3x3 {
    // Normalizes each column to unit scale
    func normalized() -> simd_float3x3 {
        return simd_float3x3(simd.normalize(columns.0),
                             simd.normalize(columns.1),
                             simd.normalize(columns.2))
    }

    var eulerAngles: SIMD3<Float> {
        let M = self.normalized()

        let R11 = M.columns.0.x
        let R12 = M.columns.1.x
        let R13 = M.columns.2.x

        let R21 = M.columns.0.y
        let R22 = M.columns.1.y
        let R23 = M.columns.2.y

        let R31 = M.columns.0.z
        let R32 = M.columns.1.z
        let R33 = M.columns.2.z

        if abs(R31) != 1.0 {
            let t1 = -asin(R31)
            let t2 = .pi - t1
            let c1 = cos(t1)
            let c2 = cos(t2)
            let psi1 = atan2(R32 / c1, R33 / c1)
            let psi2 = atan2(R32 / c2, R33 / c2)
            let phi1 = atan2(R21 / c1, R11 / c1)
            let phi2 = atan2(R21 / c2, R11 / c2)
            return SIMD3<Float>(psi1, t1, phi1)
        } else {
            let phi: Float = 0.0 // arbitrary
            if R31 == -1 {
                let t = Float.pi / 2
                let psi = phi + atan2(R12, R13)
                return SIMD3<Float>(psi, t, phi)
            } else {
                let t = -Float.pi / 2
                let psi = -phi + atan2(-R12, -R13)
                return SIMD3<Float>(psi, t, phi)
            }
        }
    }
}
