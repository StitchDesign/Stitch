//
//  GraphState.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/9/24.
//

import Foundation
import StitchSchemaKit
import StitchEngine

extension GraphState {
    @MainActor
    func children(of parent: NodeId) -> NodeViewModels {
        self.layerNodes.values.filter { layerNode in
            layerNode.layerNode?.layerGroupId == parent
        }
    }
    
    // TODO: use a specific GraphId
    @MainActor
    var projectId: UUID { self.id }
                
    // TODO: remove
    @MainActor var graphMovement: GraphMovementObserver {
        self.documentDelegate?.graphMovement ?? .init()
    }
}
