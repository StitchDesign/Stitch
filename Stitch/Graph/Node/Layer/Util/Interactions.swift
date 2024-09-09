//
//  Interactions.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/28/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// TODO: if we delete a patch node, we need to also potentially remove its id from a layer node whose interactionsDict contained that id
extension GraphState {
    @MainActor
    func getDragInteractionIds(for layerNodeId: LayerNodeId) -> IdSet {
        self.dragInteractionNodes.get(layerNodeId) ?? .init()
    }
    
    // Returns scroll interaction id
    @MainActor
    func getScrollInteractionIds(for layerNodeId: LayerNodeId) -> IdSet {
        self.scrollInteractionNodes.get(layerNodeId) ?? .init()
    }
    
    @MainActor
    func getPressInteractionIds(for layerNodeId: LayerNodeId) -> IdSet {
        self.pressInteractionNodes.get(layerNodeId) ?? .init()
    }
    
    @MainActor
    func hasInteraction(_ layerNodeId: LayerNodeId?) -> Bool {
        guard let layerNodeId = layerNodeId else {
            return false
        }
        
        return !getDragInteractionIds(for: layerNodeId).isEmpty
        || !getScrollInteractionIds(for: layerNodeId).isEmpty
        || !getPressInteractionIds(for: layerNodeId).isEmpty
    }
}

extension NodeViewModel {
    
    /// Get assigned layer id in this patch node's input.
    /// Non-nil just if (1) patch node can be assigned to a layer and (2) actually is assigned..
    @MainActor
    func getInteractionId() -> LayerNodeId? {
        if self.layerNode.isDefined {
            return nil
        }
        
        return self
            // Assumes assigned-layer alwauy in first input
            .getInputRowObserver(0)?
            // We always ignore loops; just use first value in loop
            .allLoopedValues.first?
            .getInteractionId
    }
}
