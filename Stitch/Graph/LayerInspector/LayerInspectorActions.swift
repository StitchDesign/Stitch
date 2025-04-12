//
//  LayerInspectorActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/21/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit


extension GraphState {
    // TODO: cache these for perf
    @MainActor
    var nonEditModeSelectedLayerInLayerSidebar: NodeId? {
        self.sidebarSelectionState.all.first
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
        
        guard let node = state.visibleGraph.getNodeViewModel(nodeId),
              let _ = node.layerNode else {
            log("LayerInputAddedToGraph: could not add Layer Input to graph")
            fatalErrorIfDebug()
            return
        }
        
        state.handleLayerInputAdded(nodeId: nodeId,
                                    coordinate: coordinate)
        
        state.encodeProjectInBackground()
    }
}

extension StitchDocumentViewModel {
    @MainActor
    func handleLayerInputAdded(nodeId: NodeId,
                               coordinate: LayerInputType) {
        
        let layerInput: LayerInputPort = coordinate.layerInput
        
        let addLayerInput = { (nodeId: NodeId) in
            self.addLayerInputToGraph(nodeId: nodeId,
                                      coordinate: coordinate)
        }
        
        if let multiselectInputs = self.visibleGraph.propertySidebar.inputsCommonToSelectedLayers,
           let layerMultiselectInput = multiselectInputs.first(where: { $0 == layerInput}) {
            layerMultiselectInput.multiselectObservers(self.visibleGraph).forEach { observer in
                addLayerInput(observer.packedRowObserver.id.nodeId)
            }
        } else {
            addLayerInput(nodeId)
        }
    }
    
    
    @MainActor
    func addLayerInputToGraph(nodeId: NodeId,
                              coordinate: LayerInputType) {
        
        guard let node = self.visibleGraph.getNodeViewModel(nodeId),
              let layerNode = node.layerNode else {
            log("LayerInputAddedToGraph: could not add Layer Input to graph")
            fatalErrorIfDebug()
            return
        }
        
        let layerInputData = layerNode[keyPath: coordinate.layerNodeKeyPath]
        
        self.layerInputAddedToGraph(node: node,
                                    input: layerInputData,
                                    coordinate: coordinate)
    }
}

extension GraphState {
    @MainActor
    func resetLayerInputsCache(layerNode: LayerNodeViewModel) {
        layerNode.resetInputCanvasItemsCache()

        // Reset graph cache to get new nodes to appear
        // Dispatch needed for fix
        DispatchQueue.main.async { [weak self] in
            self?.visibleNodesViewModel.resetVisibleCanvasItemsCache()
        }
    }
}

extension StitchDocumentViewModel {
    
    @MainActor
    func layerInputAddedToGraph(node: NodeViewModel,
                                input: InputLayerNodeRowData,
                                coordinate: LayerInputType,
                                position: CGPoint? = nil) {
                
        let nodeId = node.id
        
        // When adding an entire input to the graph, we don't worry about unpacked state etc.
        let unpackedPortParentFieldGroupType: FieldGroupType? = nil
        let unpackedPortIndex: Int? = nil
        
        input.canvasObserver = CanvasItemViewModel(
            id: .layerInput(.init(
                node: nodeId,
                keyPath: coordinate)),
            position: position ?? self.newCanvasItemInsertionLocation,
            zIndex: self.visibleGraph.highestZIndex + 1,
            // Put newly-created LIG into graph's current traversal level
            parentGroupNodeId: self.groupNodeFocused?.asNodeId,
            inputRowObservers: [input.rowObserver],
            outputRowObservers: [])
        
        input.canvasObserver?.initializeDelegate(node,
                                                 unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                                                 unpackedPortIndex: unpackedPortIndex)
        
        // Subscribe inspector row ui data to the row data's canvas item
        input.inspectorRowViewModel.canvasItemDelegate = input.canvasObserver
        
        // TODO: why do we have to do this?
        if let layerNode = node.layerNode {
            self.visibleGraph.resetLayerInputsCache(layerNode: layerNode)
        }
        
        self.visibleGraph.propertySidebar.selectedProperty = nil
    }
}

struct LayerOutputAddedToGraph: StitchDocumentEvent {
    
    let nodeId: NodeId
    let portId: Int
    
    func handle(state: StitchDocumentViewModel) {
        
        // log("LayerOutputAddedToGraph: nodeId: \(nodeId)")
        // log("LayerOutputAddedToGraph: coordinate: \(coordinate)")
        let graph = state.visibleGraph
        
        guard let node = graph.getNodeViewModel(nodeId),
              let layerNode = node.layerNode,
              let outputPort = layerNode.outputPorts[safe: portId] else {
            log("LayerOutputAddedToGraph: could not add Layer Output to graph")
            fatalErrorIfDebug()
            return
        }
        
        graph.layerOutputAddedToGraph(node: node,
                                      output: outputPort,
                                      portId: portId,
                                      groupNodeFocused: state.groupNodeFocused?.groupNodeId,
                                      insertionLocation: state.newCanvasItemInsertionLocation)
                
        state.encodeProjectInBackground()
    }
}

extension GraphState {
    @MainActor
    func layerOutputAddedToGraph(node: NodeViewModel,
                                 output: OutputLayerNodeRowData,
                                 portId: Int,
                                 groupNodeFocused: NodeId?,
                                 insertionLocation: CGPoint) {
        
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
            position: insertionLocation,
            zIndex: self.highestZIndex + 1,
            // Put newly-created LIG into graph's current traversal level
            parentGroupNodeId: groupNodeFocused,
            inputRowObservers: [],
            outputRowObservers: [output.rowObserver])
        
        output.canvasObserver?.initializeDelegate(node,
                                                  unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                                                  unpackedPortIndex: unpackedPortIndex)
        
        // Subscribe inspector row ui data to the row data's canvas item
        output.inspectorRowViewModel.canvasItemDelegate = output.canvasObserver
        
        self.propertySidebar.selectedProperty = nil
    }
}
