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

        let layerInputData = layerNode[keyPath: coordinate.layerNodeKeyPath]
        state.layerInputAddedToGraph(node: node,
                                     input: layerInputData,
                                     coordinate: coordinate)
        
        return .shouldPersist
    }
}

extension GraphState {
    
    @MainActor
    func layerInputAddedToGraph(node: NodeViewModel,
                                input: InputLayerNodeRowData,
                                coordinate: LayerInputType) {
        
        let nodeId = node.id
        
        input.canvasObserver = .init(
            id: .layerInput(.init(
                node: nodeId,
                keyPath: coordinate)),
            position: self.newLayerPropertyLocation,
            zIndex: self.highestZIndex + 1,
            // Put newly-created LIG into graph's current traversal level
            parentGroupNodeId: self.groupNodeFocused,
            inputRowObservers: [input.rowObserver],
            outputRowObservers: [],
            nodeDelegate: node)
        
        self.graphUI.propertySidebar.selectedProperty = nil
        
        self.maybeCreateLLMAddLayerInput(nodeId, coordinate)
    }
}

struct LayerOutputAddedToGraph: GraphEventWithResponse {
    
    let nodeId: NodeId
    let portId: Int
    
    func handle(state: GraphState) -> GraphResponse {
        
        // log("LayerOutputAddedToGraph: nodeId: \(nodeId)")
        // log("LayerOutputAddedToGraph: coordinate: \(coordinate)")
        
        guard let node = state.getNodeViewModel(nodeId),
              let layerNode = node.layerNode,
              let outputPort = layerNode.outputPorts[safe: portId] else {
            log("LayerOutputAddedToGraph: could not add Layer Output to graph")
            fatalErrorIfDebug()
            return .noChange
        }
        
        state.layerOutputAddedToGraph(node: node,
                                      output: outputPort,
                                      portId: portId)
                
        return .shouldPersist
    }
}

extension GraphState {
    
    @MainActor
    func layerOutputAddedToGraph(node: NodeViewModel,
                                 output: OutputLayerNodeRowData,
                                 portId: Int) {
        
        output.canvasObserver = .init(
            id: .layerOutput(.init(node: node.id,
                                   portId: portId)),
            position: self.newLayerPropertyLocation,
            zIndex: self.highestZIndex + 1,
            // Put newly-created LIG into graph's current traversal level
            parentGroupNodeId: self.groupNodeFocused,
            inputRowObservers: [],
            outputRowObservers: [output.rowObserver],
            nodeDelegate: node)
        
        self.graphUI.propertySidebar.selectedProperty = nil
        
        self.maybeCreateLLMAddLayerOutput(node.id, portId)
    }
}

extension GraphUIState {
    func layerPropertyTapped(_ property: LayerInspectorRowId) {
        let alreadySelected = self.propertySidebar.selectedProperty == property
                
        if alreadySelected {
            self.propertySidebar.selectedProperty = nil
        } else {
            self.propertySidebar.selectedProperty = property
        }
    }
}
