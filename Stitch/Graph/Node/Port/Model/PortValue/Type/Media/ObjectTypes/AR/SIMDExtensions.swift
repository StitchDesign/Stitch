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

// Extension to create a 4x4 rotation matrix from Euler angles
extension simd_float4x4 {
    init(rotationZYX eulerAngles: SIMD3<Float>) {
        let quaternion = simd_quatf(euler: eulerAngles)
        self.init(quaternion: quaternion)
    }
    
    // Create a 4x4 rotation matrix from a quaternion
    init(quaternion: simd_quatf) {
        self.init()
        let x = quaternion.vector.x
        let y = quaternion.vector.y
        let z = quaternion.vector.z
        let w = quaternion.vector.w
        
        let x2 = x * x
        let y2 = y * y
        let z2 = z * z
        let xy = x * y
        let xz = x * z
        let yz = y * z
        let wx = w * x
        let wy = w * y
        let wz = w * z
        
        self.columns = (
            simd_float4(1 - 2 * (y2 + z2), 2 * (xy + wz), 2 * (xz - wy), 0),
            simd_float4(2 * (xy - wz), 1 - 2 * (x2 + z2), 2 * (yz + wx), 0),
            simd_float4(2 * (xz + wy), 2 * (yz - wx), 1 - 2 * (x2 + y2), 0),
            simd_float4(0, 0, 0, 1)
        )
    }

    // Extension to create a 4x4 matrix from position, scale, and rotation
    init(position: SIMD3<Float>, scale: SIMD3<Float>, rotation: SIMD3<Float>) {
        let scaleMatrix = simd_float4x4(diagonal: SIMD4(scale, 1))
        let rotationMatrix = simd_float4x4(rotationZYX: rotation)
        let translationMatrix = simd_float4x4(
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(position.x, position.y, position.z, 1)
        )
        
        // Combine transformations: translation * rotation * scale
        self = translationMatrix * rotationMatrix * scaleMatrix
    }
}

// Extension to create a quaternion from Euler angles
extension simd_quatf {
    init(euler angles: SIMD3<Float>) {
        // Convert Euler angles to quaternion using the ZYX convention
        let c1 = cos(angles.z / 2)
        let s1 = sin(angles.z / 2)
        let c2 = cos(angles.y / 2)
        let s2 = sin(angles.y / 2)
        let c3 = cos(angles.x / 2)
        let s3 = sin(angles.x / 2)
        
        let w = c1 * c2 * c3 + s1 * s2 * s3
        let x = c1 * c2 * s3 - s1 * s2 * c3
        let y = c1 * s2 * c3 + s1 * c2 * s3
        let z = s1 * c2 * c3 - c1 * s2 * s3
        
        self.init(ix: x, iy: y, iz: z, r: w)
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
