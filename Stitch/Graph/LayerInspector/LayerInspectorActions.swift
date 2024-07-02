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

    // just pass in LayerInspectorRowId and switch on that;
    // don't need two actions
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
                
        state.layerInputAddedToGraph(node: node, 
                                     input: input,
                                     coordinate: coordinate)
        
        return .shouldPersist
    }
}

extension GraphState {
    
    @MainActor
    func layerInputAddedToGraph(node: NodeViewModel,
                                input: NodeRowObserver,
                                coordinate: LayerInputType) {
        
        let nodeId = node.id
        
        input.canvasUIData = .init(
            id: .layerInputOnGraph(.init(
                node: nodeId,
                keyPath: coordinate)),
            position: self.newNodeCenterLocation,
            zIndex: self.highestZIndex + 1,
            // Put newly-created LIG into graph's current traversal level
            parentGroupNodeId: self.groupNodeFocused,
            nodeDelegate: node)
        
        self.graphUI.propertySidebar.selectedProperties = nil
        
        self.maybeCreateLLMAddLayerInput(nodeId, coordinate)
    }
}

struct LayerOutputAddedToGraph: GraphEventWithResponse {
    
    let nodeId: NodeId
    let coordinate: LayerOutputOnGraphId
    
    func handle(state: GraphState) -> GraphResponse {
        
        // log("LayerOutputAddedToGraph: nodeId: \(nodeId)")
        // log("LayerOutputAddedToGraph: coordinate: \(coordinate)")
        
        guard let node = state.getNodeViewModel(coordinate.nodeId),
              let output = node.getOutputRowObserver(coordinate.portId) else {
            log("LayerOutputAddedToGraph: could not add Layer Output to graph")
            fatalErrorIfDebug()
            return .noChange
        }
        
        state.layerOutputAddedToGraph(node: node,
                                      output: output,
                                      portId: coordinate.portId)
                
        return .shouldPersist
    }
}

extension GraphState {
    
    @MainActor
    func layerOutputAddedToGraph(node: NodeViewModel,
                                 output: NodeRowObserver,
                                 portId: Int) {
        
        output.canvasUIData = .init(
            id: .layerOutputOnGraph(.init(portId: portId,
                                          nodeId: node.id)),
            position: self.newNodeCenterLocation,
            zIndex: self.highestZIndex + 1,
            // Put newly-created LIG into graph's current traversal level
            parentGroupNodeId: self.groupNodeFocused,
            nodeDelegate: node)
        
        self.graphUI.propertySidebar.selectedProperties = nil
        
        self.maybeCreateLLMAddLayerOutput(node.id, portId)
    }
}

extension GraphUIState {
    func layerPropertyTapped(_ property: LayerInspectorRowId) {
        let alreadySelected = self.propertySidebar.selectedProperties == property
                
        if alreadySelected {
            self.propertySidebar.selectedProperties = nil
        } else {
            self.propertySidebar.selectedProperties = property
        }
    }
}
