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
    
//    let coordinate: LayerInputType
    let layerInput: LayerInputPort
    
    func handle(state: StitchDocumentViewModel) {
        state.handleLayerInputAdded(nodeId: nodeId,
                                    layerInput: layerInput)
        state.encodeProjectInBackground()
    }
}

extension StitchDocumentViewModel {
    
    @MainActor
    func handleLayerInputAdded(nodeId: NodeId,
                               layerInput: LayerInputPort) {
        
        let addLayerInput = { (nodeId: NodeId) in
            self.addLayerInputToGraph(nodeId: nodeId, layerInput: layerInput)
        }
        
        if let multiselectInputs = self.visibleGraph.propertySidebar.inputsCommonToSelectedLayers,
           let layerMultiselectInput = multiselectInputs.first(where: { $0 == layerInput}) {
            layerMultiselectInput.multiselectObservers(self.visibleGraph).forEach { observer in
                // Note: we cannot add "whole input" to canvas if one field is already on canvas
                if let packedRow = observer.packedRowObserverOnlyIfPacked {
                    addLayerInput(packedRow.id.nodeId)
                }
            }
        } else {
            addLayerInput(nodeId)
        }
    }
    
    
    @MainActor
    func addLayerInputToGraph(nodeId: NodeId,
                              layerInput: LayerInputPort) {
        
        guard let node = self.visibleGraph.getNode(nodeId) else {
            log("LayerInputAddedToGraph: could not add Layer Input to graph")
            fatalErrorIfDebug()
            return
        }
        
        self.layerInputAddedToGraph(node: node, layerInput: layerInput)
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
                                layerInput: LayerInputPort,
                                position: CGPoint? = nil) {
                
        let nodeId = node.id
        
        guard let layerNode = self.visibleGraph.getLayerNode(nodeId) else {
            fatalErrorIfDebug()
            return
        }
        
        guard layerNode[keyPath: layerInput.layerNodeKeyPath].mode == .packed else {
            log("Tried to add whole layer input to canvas when layer input was in unpack mode")
            return
        }
        
        let input: InputLayerNodeRowData = layerNode[keyPath: layerInput.packedLayerInputKeyPath]
                
        // When adding an entire input to the graph, we don't worry about unpacked state etc.
        let unpackedPortParentFieldGroupType: FieldGroupType? = nil
        let unpackedPortIndex: Int? = nil
        
        let canvasItemId: CanvasItemId = .layerInput(LayerInputCoordinate(
            node: nodeId,
            keyPath: .init(layerInput: layerInput, portType: .packed)))
        
        let canvasItem = CanvasItemViewModel(
            id: canvasItemId,
            position: position ?? self.newCanvasItemInsertionLocation,
            zIndex: self.visibleGraph.highestZIndex + 1,
            // Put newly-created LIG into graph's current traversal level
            parentGroupNodeId: self.groupNodeFocused?.asNodeId,
            inputRowObservers: [input.rowObserver],
            outputRowObservers: [])
                
        canvasItem.assignNodeReferenceAndUpdateFieldGroupsOnRowViewModels(
            node,
            activeIndex: self.activeIndex,
            unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
            unpackedPortIndex: unpackedPortIndex,
            graph: self.visibleGraph)
        
        input.canvasObserver = canvasItem
        
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
        
        guard let node = graph.getNode(nodeId),
              let layerNode = node.layerNode,
              let outputPort = layerNode.outputPorts[safe: portId] else {
            log("LayerOutputAddedToGraph: could not add Layer Output to graph")
            fatalErrorIfDebug()
            return
        }
        
        graph.layerOutputAddedToGraph(node: node,
                                      output: outputPort,
                                      activeIndex: state.activeIndex,
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
                                 activeIndex: ActiveIndex,
                                 portId: Int,
                                 groupNodeFocused: NodeId?,
                                 insertionLocation: CGPoint) {
        
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
        
        output.canvasObserver?.assignNodeReferenceAndUpdateFieldGroupsOnRowViewModels(node,
                                                  activeIndex: activeIndex,
                                                  unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                                                  unpackedPortIndex: unpackedPortIndex,
                                                  graph: self)
        
        // Subscribe inspector row ui data to the row data's canvas item
        output.inspectorRowViewModel.canvasItemDelegate = output.canvasObserver
        
        self.propertySidebar.selectedProperty = nil
    }
}
