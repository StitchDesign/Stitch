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
              let layerNode = node.layerNode else {
            log("LayerInputAddedToGraph: could not add Layer Input to graph")
            fatalErrorIfDebug()
            return .noChange
        }
                
        let layerInputObserver = layerNode[keyPath: coordinate.layerNodeKeyPath]
        layerInputObserver.canvasObsever = .init(
            id: .layerInput(.init(
                node: nodeId,
                keyPath: coordinate)),
            position: state.newNodeCenterLocation,
            zIndex: state.highestZIndex + 1,
            // Put newly-created LIG into graph's current traversal level
            parentGroupNodeId: state.groupNodeFocused,
            nodeDelegate: node)
        
        state.maybeCreateLLMAddLayerInput(nodeId, coordinate)
        
        return .shouldPersist
    }
}

struct LayerOutputAddedToGraph: GraphEventWithResponse {
    
    let nodeId: NodeId
    let coordinate: NodeIOPortType
    
    func handle(state: GraphState) -> GraphResponse {
        
        // log("LayerOutputAddedToGraph: nodeId: \(nodeId)")
        // log("LayerOutputAddedToGraph: coordinate: \(coordinate)")
        
        guard let node = state.getNodeViewModel(nodeId),
              let portId = coordinate.portIndex,
              let layerNode = node.layerNode,
              let outputPort = layerNode.outputPorts[safe: portId] else {
            log("LayerOutputAddedToGraph: could not add Layer Output to graph")
            fatalErrorIfDebug()
            return .noChange
        }
        
        outputPort.canvasObsever = .init(
            id: .layerOutput(.init(node: nodeId, portId: portId)),
            position: state.newNodeCenterLocation,
            zIndex: state.highestZIndex + 1,
            // Put newly-created LIG into graph's current traversal level
            parentGroupNodeId: state.groupNodeFocused,
            nodeDelegate: node)
        
        state.maybeCreateLLMAddLayerOutput(nodeId, portId)
        
        return .shouldPersist
    }
}

extension GraphUIState {
    func layerPropertyTapped(_ property: LayerInspectorRowId) {
        let alreadySelected = self.propertySidebar.selectedProperties.contains(property)
        
        if alreadySelected {
            self.propertySidebar.selectedProperties.remove(property)
        } else {
            self.propertySidebar.selectedProperties.insert(property)
        }
    }
}
