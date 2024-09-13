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
        self.sidebarSelectionState.inspectorFocusedLayers.first?.id
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

struct LayerInputAddedToGraph: StitchDocumentEvent {

    // just pass in LayerInspectorRowId and switch on that;
    // don't need two actions
    let nodeId: NodeId
    let coordinate: LayerInputType
    
    func handle(state: StitchDocumentViewModel) {
        
        // log("LayerInputAddedToGraph: nodeId: \(nodeId)")
        // log("LayerInputAddedToGraph: coordinate: \(coordinate)")
        
        guard let node = state.getNodeViewModel(nodeId),
              let layerNode = node.layerNode else {
            log("LayerInputAddedToGraph: could not add Layer Input to graph")
            fatalErrorIfDebug()
            return
        }
        
        handleLayerInputAddedToGraph(state: state, 
                                     nodeId: nodeId,
                                     coordinate: coordinate)
        
        state.graph.encodeProjectInBackground()
    }
}

@MainActor
func handleLayerInputAddedToGraph(state: StitchDocumentViewModel,
                                  nodeId: NodeId,
                                  coordinate: LayerInputType) {
    
    let layerInput: LayerInputPort = coordinate.layerInput
    
    if let multiselectInputs = state.graphUI.propertySidebar.inputsCommonToSelectedLayers,
       let layerMultiselectInput = multiselectInputs.first(where: { $0 == layerInput}) {
        
        
        layerMultiselectInput.multiselectObservers(state.visibleGraph).forEach { observer in
            addLayerInputToGraph(state: state,
                                 nodeId: observer.rowObserver.id.nodeId,
                                 coordinate: coordinate)
        }
    }
    
    else {
        addLayerInputToGraph(state: state,
                             nodeId: nodeId,
                             coordinate: coordinate)
    }
}


@MainActor
func addLayerInputToGraph(state: StitchDocumentViewModel,
                          nodeId: NodeId,
                          coordinate: LayerInputType) {
    
    guard let node = state.getNodeViewModel(nodeId),
          let layerNode = node.layerNode else {
        log("LayerInputAddedToGraph: could not add Layer Input to graph")
        fatalErrorIfDebug()
        return
    }

    let layerInputData = layerNode[keyPath: coordinate.layerNodeKeyPath]
    state.visibleGraph.layerInputAddedToGraph(node: node,
                                              input: layerInputData,
                                              coordinate: coordinate)
}

extension GraphState {
    
    @MainActor
    func layerInputAddedToGraph(node: NodeViewModel,
                                input: InputLayerNodeRowData,
                                coordinate: LayerInputType) {
        
        guard let document = self.documentDelegate else {
            fatalErrorIfDebug()
            return
        }
        
        let nodeId = node.id
        
        // When adding an entire input to the graph, we don't worry about unpacked state etc.
        let unpackedPortParentFieldGroupType: FieldGroupType? = nil
        let unpackedPortIndex: Int? = nil
        
        input.canvasObserver = CanvasItemViewModel(
            id: .layerInput(.init(
                node: nodeId,
                keyPath: coordinate)),
            position: document.newLayerPropertyLocation,
            zIndex: document.visibleGraph.highestZIndex + 1,
            // Put newly-created LIG into graph's current traversal level
            parentGroupNodeId: document.graphUI.groupNodeFocused?.asNodeId,
            inputRowObservers: [input.rowObserver],
            outputRowObservers: [],
            unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
            unpackedPortIndex: unpackedPortIndex)
        
        input.canvasObserver?.initializeDelegate(node,
                                                 unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                                                 unpackedPortIndex: unpackedPortIndex)
        
        // Subscribe inspector row ui data to the row data's canvas item
        input.inspectorRowViewModel.canvasItemDelegate = input.canvasObserver
        
        document.graphUI.propertySidebar.selectedProperty = nil
        
        document.maybeCreateLLMAddLayerInput(nodeId, coordinate)
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
        
        guard let document = self.documentDelegate else {
            fatalErrorIfDebug()
            return
        }
        // Not relevant for output
        let unpackedPortParentFieldGroupType: FieldGroupType? = nil
        let unpackedPortIndex: Int? = nil
        
        output.canvasObserver = CanvasItemViewModel(
            id: .layerOutput(.init(node: node.id,
                                   portId: portId)),
            position: document.newLayerPropertyLocation,
            zIndex: self.highestZIndex + 1,
            // Put newly-created LIG into graph's current traversal level
            parentGroupNodeId: self.groupNodeFocused,
            inputRowObservers: [],
            outputRowObservers: [output.rowObserver],
            unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
            unpackedPortIndex: unpackedPortIndex)
        
        output.canvasObserver?.initializeDelegate(node,
                                                  unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                                                  unpackedPortIndex: unpackedPortIndex)
        
        // Subscribe inspector row ui data to the row data's canvas item
        output.inspectorRowViewModel.canvasItemDelegate = output.canvasObserver
        
        document.graphUI.propertySidebar.selectedProperty = nil
        
        document.maybeCreateLLMAddLayerOutput(node.id, portId)
    }
}
