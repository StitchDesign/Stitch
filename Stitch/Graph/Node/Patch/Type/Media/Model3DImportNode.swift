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
        let matrix: matrix_float4x4 = matrix_float4x4(position: simd_float3(Float(transform.positionX), Float(transform.positionY), Float(transform.positionZ)), scale: simd_float3(Float(transform.scaleX), Float(transform.scaleY), Float(transform.scaleZ)), rotationZYX: simd_float3(Float(transform.rotationX), Float(transform.rotationY), Float(transform.rotationZ)))
        
        let model3DEntity = media.mediaObject.model3DEntity
        
        // Update transform
        model3DEntity?.applyMatrix(newMatrix: matrix)
        
        switch model3DEntity?.entityStatus {
        case .loaded(let entity):
            // Update animation
            model3DEntity?.isAnimating = animating
            
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
