//
//  Model3DImportNode.swift
//  Stitch
//
//  Created by Nicholas Arner on 8/17/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import RealityKit

struct Model3DPatchNode: PatchNodeDefinition {
    static let patch = Patch.model3DImport

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.asyncMedia(nil)],
                    label: ""
                ),
                .init(
                    defaultValues: [.bool(false)],
                    label: "Animating"
                ),
                .init(
                    defaultValues: [.transform(DEFAULT_STITCH_TRANSFORM)],
                    label: "Transform"
                )
            ],
            outputs: [
                .init(
                    label: "",
                    type: .media
                )
            ]
        )
    }

    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        MediaEvalOpObserver()
    }
}

@MainActor
func model3DImportEval(node: PatchNode) -> EvalResult {

    // get the input matrix and animation value
    // modify the 3d model
    // return the 3d model in the ouptut port

    node.loopedEval(MediaEvalOpObserver.self) { values, asyncObserver, _ in
        guard let media = asyncObserver.getUniqueMedia(from: values.first) else {
            return node.defaultOutputs
        }
        
        let animating = values[Model3DImportNodeIndices.animating].getBool ?? false
        
        let transform = values[Model3DImportNodeIndices.matrix].getTransform ?? StitchTransform()
        let matrix: matrix_float4x4 = matrix_float4x4(from: transform)
        
        guard let model3DEntity = media.mediaObject.model3DEntity else {
            return node.defaultOutputs
        }
        
        //transform is empty, so use the original transform value
        if transform == DEFAULT_STITCH_TRANSFORM {
            let position: simd_float3
            if let originalPosition = model3DEntity.originalTransformMatrix?.position {
                position = simd_float3(originalPosition)
            } else {
                position = simd_float3(0.0, 0.0, 0.0)
            }
            
            let scale: simd_float3
            if let originalScale = model3DEntity.originalTransformMatrix?.scale {
                scale = simd_float3(originalScale)
            } else {
                scale = simd_float3(1.0, 1.0, 1.0)
            }

            let rotationX = Double(model3DEntity.originalTransformMatrix?.rotationInRadians.x ?? 0.0)
            let rotationY = Double(model3DEntity.originalTransformMatrix?.rotationInRadians.y ?? 0.0)
            let rotationZ = Double(model3DEntity.originalTransformMatrix?.rotationInRadians.z ?? 0.0)

            transform = StitchTransform(
                positionX: Double(position.x),
                positionY: Double(position.y),
                positionZ: Double(position.z),
                scaleX: Double(scale.x),
                scaleY: Double(scale.y),
                scaleZ: Double(scale.z),
                rotationX: rotationX,
                rotationY: rotationY,
                rotationZ: rotationZ
            )
        }

        let position = simd_float3(Float(transform.positionX), Float(transform.positionY), Float(transform.positionZ))
        let scale = simd_float3(Float(transform.scaleX), Float(transform.scaleY), Float(transform.scaleZ))
        let rotationZYX = simd_float3(Float(transform.rotationX), Float(transform.rotationY), Float(transform.rotationZ))
        
        let matrix = matrix_float4x4(position: position, scale: scale, rotationZYX: rotationZYX)
        
        model3DEntity.applyMatrix(newMatrix: matrix)
        
        switch model3DEntity.entityStatus {
        case .loaded(let entity):
            // Update animation
            model3DEntity.isAnimating = animating
            return [media.portValue]
        default:
            // Return nil object if 3D model still loading or none
            return [.asyncMedia(nil)]
        }
    }
}

struct Model3DImportNodeIndices {
    static let media = 0
    static let animating = 1
    static let matrix = 2
}


import SceneKit
import simd

extension simd_float3 {
    init(_ vector: SCNVector3) {
        self.init(x: vector.x, y: vector.y, z: vector.z)
    }
}

extension SCNVector3 {
    init(_ vector: simd_float3) {
        self.init(x: vector.x, y: vector.y, z: vector.z)
    }
}
