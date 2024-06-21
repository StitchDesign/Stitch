//
//  LayerInspectorActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/21/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit


extension GraphDelegate {
    // TODO: cache these for perf
    @MainActor
    var nonEditModeSelectedLayerInLayerSidebar: NodeId? {
        self.sidebarSelectionState.nonEditModeSelections.last?.id
    }
    
    // TODO: cache these for perf
    @MainActor
    var firstLayerInLayerSidebar: NodeId? {
        self.orderedSidebarLayers.first?.id
    }
    
    // TODO: support multiple layers being focused in propety sidebar
    // TODO: cache these for perf?
    /// The single layer currently focused in the inspector
    @MainActor
    var layerFocusedInPropertyInspector: NodeId? {
        self.nonEditModeSelectedLayerInLayerSidebar ?? self.firstLayerInLayerSidebar
    }
}

struct LayerInputAddedToGraph: GraphEventWithResponse {
    
    let nodeId: NodeId
    let coordinate: LayerInputType
    
    func handle(state: GraphState) -> GraphResponse {
        
        // log("LayerInputAddedToGraph: nodeId: \(nodeId)")
        // log("LayerInputAddedToGraph: coordinate: \(coordinate)")
        
        guard let node = state.getNodeViewModel(nodeId),
              let input = node.getInputRowObserver(for: .keyPath(coordinate)) else {
            log("LayerInputAddedToGraph: could not add Layer Input to graph")
            fatalErrorIfDebug()
            return .noChange
        }
                
        input.canvasUIData = .init(
            id: .layerInputOnGraph(.init(
                node: nodeId,
                keyPath: coordinate)),
            position: state.newNodeCenterLocation,
            zIndex: state.highestZIndex + 1,
            // Put newly-created LIG into graph's current traversal level
            parentGroupNodeId: state.groupNodeFocused,
            nodeDelegate: node)
        
        return .shouldPersist
    }
}

extension GraphUIState {
    func layerPropertyTapped(_ property: LayerInputType) {
        let alreadySelected = self.propertySidebar.selectedProperties.contains(property)
        
        if alreadySelected {
            self.propertySidebar.selectedProperties.remove(property)
        } else {
            self.propertySidebar.selectedProperties.append(property)
        }
    }
}
