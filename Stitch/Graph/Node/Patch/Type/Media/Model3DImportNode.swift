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
        
        var transform = values[Model3DImportNodeIndices.matrix].getTransform ?? StitchTransform()
        var matrix: matrix_float4x4 = matrix_float4x4(from: transform)
        
        let model3DEntity = media.mediaObject.model3DEntity
                
        // Update transform
                
        //transform is empty, so use the original transform value
        if transform == DEFAULT_STITCH_TRANSFORM {
            
            guard let originalTransformMatrix = model3DEntity?.originalTransformMatrix else {
                return node.defaultOutputs
            }
            
            guard let position = model3DEntity?.originalTransformMatrix?.position else {
                return node.defaultOutputs
            }
            let positionX: Double = Double(position.x)
            let positionY: Double = Double(position.y)
            let positionZ: Double = Double(position.z)

            let scale = model3DEntity?.originalTransformMatrix?.scale
            let scaleX = roundToDecimalPlaces(Double(scale!.x), places: 2)
            let scaleY = roundToDecimalPlaces(Double(scale!.y), places: 2)
            let scaleZ = roundToDecimalPlaces(Double(scale!.z), places: 2)

            let rotationX: Double = Double((model3DEntity?.originalTransformMatrix?.rotationInRadians.x)!)
            let rotationY: Double = Double((model3DEntity?.originalTransformMatrix?.rotationInRadians.y)!)
            let rotationZ: Double = Double((model3DEntity?.originalTransformMatrix?.rotationInRadians.z)!)

            transform = StitchTransform(positionX: positionX, positionY: positionY, positionZ: positionZ, scaleX: scaleX, scaleY: scaleY, scaleZ: scaleZ, rotationX: rotationX, rotationY: rotationY, rotationZ: rotationZ)
            
            matrix = originalTransformMatrix
        } else {
            matrix = matrix_float4x4(position: simd_float3(Float(transform.positionX), Float(transform.positionY), Float(transform.positionZ)), scale: simd_float3(Float(transform.scaleX), Float(transform.scaleY), Float(transform.scaleZ)), rotationZYX: simd_float3(Float(transform.rotationX), Float(transform.rotationY), Float(transform.rotationZ)))
        }
        
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

func roundToDecimalPlaces(_ value: Double, places: Int) -> Double {
    let multiplier = pow(10.0, Double(places))
    return (value * multiplier).rounded() / multiplier
}

struct Model3DImportNodeIndices {
    static let media = 0
    static let animating = 1
    static let matrix = 2
}
