import Foundation
import StitchSchemaKit
import simd
import SceneKit

extension SIMD4 {
    var xyz: SIMD3<Scalar> {
        return SIMD3(x, y, z)
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

// Extension to create a 4x4 rotation matrix from Euler angles
extension simd_float4x4 {
    init(from transform: StitchTransform) {
        self.init(position: simd_float3(Float(transform.positionX),
                                        Float(transform.positionY),
                                        Float(transform.positionZ)),
                  scale: simd_float3(Float(transform.scaleX),
                                     Float(transform.scaleY),
                                     Float(transform.scaleZ)),
                  
                  rotationZYX: simd_float3(Float(transform.rotationX),
                                           Float(transform.rotationY),
                                           Float(transform.rotationZ)))
    }
    
    var upperLeft3x3: simd_float3x3 {
        return simd_float3x3(columns.0.xyz, columns.1.xyz, columns.2.xyz)
    }
    
    // Create a 4x4 rotation matrix from Euler angles (in radians) || TODO: This is fine, but, one layer beneath UI, convert from degrees to radians for a much smoother expereince 
    init(rotationZYX eulerAngles: SIMD3<Float>) {
        let cx = cos(eulerAngles.x), sx = sin(eulerAngles.x)
        let cy = cos(eulerAngles.y), sy = sin(eulerAngles.y)
        let cz = cos(eulerAngles.z), sz = sin(eulerAngles.z)

        let rotationMatrix = simd_float3x3(
            SIMD3<Float>(cy * cz, cy * sz, -sy),
            SIMD3<Float>(sx * sy * cz - cx * sz, sx * sy * sz + cx * cz, sx * cy),
            SIMD3<Float>(cx * sy * cz + sx * sz, cx * sy * sz - sx * cz, cx * cy)
        )

        self.init(rotationMatrix)
    }

    // Extract Euler angles (in radians) from the matrix
    var eulerAngles: SIMD3<Float> {
        let rotMatrix = rotationMatrix
        var angles = SIMD3<Float>()

        // Singularity check
        if abs(rotMatrix[0, 2]) >= 1 - 1e-6 {
            // Gimbal lock case
            angles.z = 0
            if rotMatrix[0, 2] < 0 {
                angles.y = .pi / 2
                angles.x = atan2(rotMatrix[1, 0], rotMatrix[2, 0])
            } else {
                angles.y = -.pi / 2
                angles.x = atan2(-rotMatrix[1, 0], -rotMatrix[2, 0])
            }
        } else {
            angles.y = -asin(rotMatrix[0, 2])
            angles.x = atan2(rotMatrix[1, 2] / cos(angles.y), rotMatrix[2, 2] / cos(angles.y))
            angles.z = atan2(rotMatrix[0, 1] / cos(angles.y), rotMatrix[0, 0] / cos(angles.y))
        }

        return angles
    }

    // Initialize from a 3x3 rotation matrix
    init(_ rotationMatrix: simd_float3x3) {
        self.init(
            SIMD4<Float>(rotationMatrix.columns.0, 0),
            SIMD4<Float>(rotationMatrix.columns.1, 0),
            SIMD4<Float>(rotationMatrix.columns.2, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
    }

    var position: SCNVector3 {
        SCNVector3(columns.3.x, columns.3.y, columns.3.z)
    }

    // Extract scale from the matrix
    var scale: SIMD3<Float> {
        .init(
            simd_length(SIMD3<Float>(columns.0.x, columns.0.y, columns.0.z)),
            simd_length(SIMD3<Float>(columns.1.x, columns.1.y, columns.1.z)),
            simd_length(SIMD3<Float>(columns.2.x, columns.2.y, columns.2.z))
        )
    }

    // Extract rotation matrix (3x3)
    var rotationMatrix: simd_float3x3 {
        let scale = self.scale
        return simd_float3x3(
            SIMD3<Float>(columns.0.x, columns.0.y, columns.0.z) / scale.x,
            SIMD3<Float>(columns.1.x, columns.1.y, columns.1.z) / scale.y,
            SIMD3<Float>(columns.2.x, columns.2.y, columns.2.z) / scale.z
        )
    }
    var orientation: simd_quatf {
        simd_quaternion(self)
    }
    
    var rotation: simd_quatf {
        let qw = sqrt(1 + columns.0.x + columns.1.y + columns.2.z) / 2
        let qx = (columns.2.y - columns.1.z) / (4 * qw)
        let qy = (columns.0.z - columns.2.x) / (4 * qw)
        let qz = (columns.1.x - columns.0.y) / (4 * qw)
        return simd_quatf(ix: qx, iy: qy, iz: qz, r: qw)
    }
    
    var rotationInRadians: SIMD3<Float> {
        let rotMatrix = rotationMatrix
        var angles = SIMD3<Float>()

        // Extract rotation angles using atan2 for better accuracy
        angles.y = asin(-rotMatrix[0, 2])
        
        if cos(angles.y) != 0 {
            angles.x = atan2(rotMatrix[1, 2], rotMatrix[2, 2])
            angles.z = atan2(rotMatrix[0, 1], rotMatrix[0, 0])
        } else {
            // Gimbal lock case
            angles.x = 0
            angles.z = atan2(-rotMatrix[1, 0], rotMatrix[1, 1])
        }
        
        return angles
    }


    // Convert Euler angles to degrees
    var eulerAnglesDegrees: SIMD3<Float> {
        let radians = self.eulerAngles
        return SIMD3<Float>(
            radians.x * (180 / .pi),
            radians.y * (180 / .pi),
            radians.z * (180 / .pi)
        )
    }

    // Extract quaternion from the rotation matrix
    var quaternion: simd_quatf {
        let rotMatrix = rotationMatrix
        let trace = rotMatrix[0, 0] + rotMatrix[1, 1] + rotMatrix[2, 2]

        if trace > 0 {
            let s = 0.5 / sqrt(trace + 1.0)
            return simd_quatf(
                vector: SIMD4<Float>(
                    (rotMatrix[2, 1] - rotMatrix[1, 2]) * s,
                    (rotMatrix[0, 2] - rotMatrix[2, 0]) * s,
                    (rotMatrix[1, 0] - rotMatrix[0, 1]) * s,
                    0.25 / s
                )
            )
        } else {
            if rotMatrix[0, 0] > rotMatrix[1, 1] && rotMatrix[0, 0] > rotMatrix[2, 2] {
                let s = 2.0 * sqrt(1.0 + rotMatrix[0, 0] - rotMatrix[1, 1] - rotMatrix[2, 2])
                return simd_quatf(
                    vector: SIMD4<Float>(
                        0.25 * s,
                        (rotMatrix[0, 1] + rotMatrix[1, 0]) / s,
                        (rotMatrix[0, 2] + rotMatrix[2, 0]) / s,
                        (rotMatrix[2, 1] - rotMatrix[1, 2]) / s
                    )
                )
            } else if rotMatrix[1, 1] > rotMatrix[2, 2] {
                let s = 2.0 * sqrt(1.0 + rotMatrix[1, 1] - rotMatrix[0, 0] - rotMatrix[2, 2])
                return simd_quatf(
                    vector: SIMD4<Float>(
                        (rotMatrix[0, 1] + rotMatrix[1, 0]) / s,
                        0.25 * s,
                        (rotMatrix[1, 2] + rotMatrix[2, 1]) / s,
                        (rotMatrix[0, 2] - rotMatrix[2, 0]) / s
                    )
                )
            } else {
                let s = 2.0 * sqrt(1.0 + rotMatrix[2, 2] - rotMatrix[0, 0] - rotMatrix[1, 1])
                return simd_quatf(
                    vector: SIMD4<Float>(
                        (rotMatrix[0, 2] + rotMatrix[2, 0]) / s,
                        (rotMatrix[1, 2] + rotMatrix[2, 1]) / s,
                        0.25 * s,
                        (rotMatrix[1, 0] - rotMatrix[0, 1]) / s
                    )
                )
            }
        }
    }
    
    // Create a 4x4 matrix from position, scale, and rotation
    init(position: SIMD3<Float>, scale: SIMD3<Float>, rotationZYX: SIMD3<Float>) {
        let scaleMatrix = simd_float4x4(diagonal: SIMD4(scale, 1))
        let rotationMatrix = simd_float4x4(rotationZYX: rotationZYX)
        let translationMatrix = simd_float4x4(
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(position.x, position.y, position.z, 1)
        )
        
        // Combine transformations: translation * rotation * scale
        self = translationMatrix * rotationMatrix * scaleMatrix
    }

    // Extract position matrix
    var positionMatrix: simd_float4x4 {
        var result = matrix_identity_float4x4
        result.columns.3 = SIMD4<Float>(position.x, position.y, position.z, 1)
        return result
    }

    // Extract scale matrix
    var scaleMatrix: simd_float4x4 {
        let scale = self.scale
        return simd_float4x4(diagonal: SIMD4<Float>(scale.x, scale.y, scale.z, 1))
    }
}
