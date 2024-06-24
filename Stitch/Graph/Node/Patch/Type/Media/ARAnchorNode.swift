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
                    defaultValues: [.asyncMedia(nil)],
                    label: "3D Model"
                ),
                .init(
                    defaultValues: [.matrixTransform(DEFAULT_TRANSFORM_MATRIX_ANCHOR.matrix)],
                    label: "Transform"
                )
            ],
            outputs: [
                .init(
                    label: "AR Anchor",
                    type: .media
                )
            ]
        )
    }

    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        ARAnchorObserver()
    }
}

final class ARAnchorObserver: MediaEvalOpObservable {
    // 3D model entity
    var currentMedia: GraphMediaValue?
    
    var currentLoadingMediaId: UUID?
    
    var arAnchor: AnchorEntity?

    // Created for each anchor instance
    var anchorMediaId = UUID()
    
    let mediaActor = MediaEvalOpCoordinator()

    weak var nodeDelegate: NodeDelegate?
}

@MainActor
func arAnchorEval(node: PatchNode) -> EvalResult {
    node.loopedEval(ARAnchorObserver.self) { values, mediaObserver, loopIndex in
        guard let inputModel3d = mediaObserver.getUniqueMedia(from: values.first) else {
            mediaObserver.arAnchor = nil
            return values.prevOutputs(node: node)
        }
        
        let transformMatrix = values[safe: 1]?.getMatrix ?? DEFAULT_TRANSFORM_MATRIX_ANCHOR.matrix
        
        if let anchorEntity = mediaObserver.arAnchor {
            let anchorId = mediaObserver.anchorMediaId
            
            anchorEntity.transform.matrix = transformMatrix
            let outputValue: PortValue = .asyncMedia(.init(id: anchorId,
                                                           dataType: .computed,
                                                           mediaObject: .arAnchor(anchorEntity)))
            return [outputValue]
        }
        
        // Create new anchor if 3D models changed--necessary since difficult
        // to remove old 3D models in place from an existing anchor
        let newAnchor = AnchorEntity()
        let newId = UUID()
        mediaObserver.arAnchor = newAnchor
        mediaObserver.anchorMediaId = newId
        
        // Add 3D model to anchor
        if let model3DEntity = inputModel3d.mediaObject.model3DEntity {
            switch model3DEntity.entityStatus {
            case .loading:
                model3DEntity.anchor = newAnchor
            case .loaded(let loaded3DEntity):
                newAnchor.addChild(loaded3DEntity)
            default:
                break
            }
        }
        
        newAnchor.transform.matrix = transformMatrix
        
        let outputValue: PortValue = .asyncMedia(.init(id: mediaObserver.anchorMediaId,
                                                       dataType: .computed,
                                                       mediaObject: .arAnchor(newAnchor)))
        return [outputValue]
    }
}
