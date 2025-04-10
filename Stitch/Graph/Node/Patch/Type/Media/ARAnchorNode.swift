//
//  ARAnchorNode.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/24/23.
//

import Foundation
import StitchSchemaKit
import RealityKit
struct ArAnchorNode: PatchNodeDefinition {
    static let patch = Patch.arAnchor

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.transform(DEFAULT_STITCH_TRANSFORM)],
                    label: "Transform"
                )
            ],
            outputs: [
                .init(
                    label: "AR Anchor",
                    type: .anchorEntity
                )
            ]
        )
    }

    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        ARAnchorObserver()
    }
}

final class ARAnchorObserver: MediaEvalOpObservable {
    // where 3D model entity is tored
    let mediaViewModel: MediaViewModel
    
    @MainActor var currentLoadingMediaId: UUID?
    
    @MainActor var arAnchor: AnchorEntity?

    // Created for each anchor instance
    @MainActor var anchorMediaId = UUID()
    
    let mediaActor = MediaEvalOpCoordinator()

    @MainActor weak var nodeDelegate: NodeViewModel?
    
    @MainActor init() {
        self.mediaViewModel = .init()
    }
}

extension ARAnchorObserver {
    func onPrototypeRestart() { }
}

@MainActor
func arAnchorEval(node: PatchNode) -> EvalResult {
    node.loopedEval(ARAnchorObserver.self) { values, mediaObserver, loopIndex in
        guard let transform = values.first?.getTransform else {
            mediaObserver.arAnchor = nil
            return values.prevOutputs(node: node)
        }
        
        let position = SIMD3(x: Float(transform.positionX), y: Float(transform.positionY), z: Float(transform.positionZ))
        let scale = SIMD3(x: Float(transform.scaleX), y: Float(transform.scaleY), z: Float(transform.scaleZ))
        let rotationXYZ = SIMD3(x: Float(transform.rotationX), y: Float(transform.rotationY), z: Float(transform.rotationZ))
        let transformMatrix = matrix_float4x4(position: position, scale: scale, rotationZYX: rotationXYZ)
        let outputValue = PortValue.anchorEntity(node.id)
        
        if let anchorEntity = mediaObserver.arAnchor {            
            anchorEntity.transform.matrix = transformMatrix
            return [outputValue]
        }
        
        // Create new anchor if 3D models changed--necessary since difficult
        // to remove old 3D models in place from an existing anchor
        let newAnchor = AnchorEntity()
        let newId = UUID()
        mediaObserver.arAnchor = newAnchor
        mediaObserver.anchorMediaId = newId
        
        newAnchor.transform.matrix = transformMatrix
        return [outputValue]
    }
}
