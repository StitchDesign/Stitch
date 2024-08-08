//
//  ARUtils.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 11/29/22.
//

import ARKit
import RealityKit
import simd
import StitchSchemaKit

extension Transform {
    /// Creates a matrix from scratch.
    static func createMatrix(positionX: Float,
                             positionY: Float,
                             positionZ: Float,
                             scaleX: Float,
                             scaleY: Float,
                             scaleZ: Float,
                             rotationX: Float,
                             rotationY: Float,
                             rotationZ: Float,
                             rotationReal: Float) -> Transform {
        let position = SIMD3([positionX, positionY, positionZ])
        let scale = SIMD3([scaleX, scaleY, scaleZ])
        
        // MARK: we swap Y with X, hack but works
        let rotation = SIMD3([rotationY, rotationX, rotationZ])

        let matrix = simd_float4x4(position: position,
                                   scale: scale,
                                   rotation: rotation)
        
        return .init(matrix: matrix)
    }

    var position: SCNVector3 {
        self.matrix.position
    }
}

extension StitchMatrix: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.hashValue)
    }
}

extension StitchMatrix {
    var position: SCNVector3 {
        SCNVector3(columns.3.x, columns.3.y, columns.3.z)
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

    var scale: SCNVector3 {
        get {
            SCNVector3(columns.0.x, columns.1.y, columns.2.z)
        }
        set(newvalue) {
            self.columns.0.x = newvalue.x
            self.columns.1.y = newvalue.y
            self.columns.2.z = newvalue.z
        }
    }
}

extension SCNVector3 {
    static func==(lhs: SCNVector3, rhs: SCNVector3) -> Bool {
        lhs.x == rhs.x &&
            lhs.y == rhs.y &&
            lhs.z == rhs.z
    }
}

extension ARFrame {
    func convertToUIImage(context: CIContext) async -> UIImage? {
        let image = self.capturedImage
        let ciImage = CIImage(cvImageBuffer: image)

        // Send image to graph if successfully created
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        // Rotate image on iPhone
        let uiImage = GraphUIState.isPhoneDevice ? UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
            : UIImage(cgImage: cgImage)

        return uiImage
    }
}

extension Entity {
    // MARK: eval logic for model 3D patch node
    func applyMatrix(newMatrix: StitchMatrix) {
        // Set translation
        let position = newMatrix.position
        let translation = SIMD3([position.x, position.y, position.z])
        self.transform.translation = translation

        // Set orientation
        self.smoothOrientationChange(newOrientation: newMatrix.orientation)

        // Set scale
        self.scale = SIMD3(newMatrix.scale)
    }

    private func smoothOrientationChange(newOrientation: simd_quatf) {
        // Set orientation from the raycast. Setting too often creates a jarring experience.
        let tilt = abs(newOrientation.vector.x)
        let threshold: Float = .pi / 2 * 0.75

        if tilt > threshold {
            self.orientation = newOrientation
        }
    }
}

extension Transform: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        try self.init(matrix: container.decode(StitchMatrix.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(self.matrix)
    }
}

typealias EntitySequence = [Entity.ChildCollection.Element]

extension AnchorEntity {
    /// Finds and removes a sequence of entities from an `AnchorEntity`.
    func removeAllEntities(_ entities: EntitySequence) {
        entities.forEach { otherEntity in
            if let entityToRemove = self.findEntity(named: otherEntity.name) {
                self.removeChild(entityToRemove)
            }
        }
    }
}
