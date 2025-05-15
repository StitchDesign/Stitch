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

    let layerInput: LayerInputPort
    
    func handle(state: StitchDocumentViewModel) {
        state.handleLayerInputAdded(layerInput: layerInput,
                                    draggedOutput: nil)
        state.encodeProjectInBackground()
    }
}

extension StitchDocumentViewModel {
    
    @MainActor
    func handleLayerInputAdded(layerInput: LayerInputPort,
                               // non-nil just when we dragged an edge over
                               draggedOutput: OutputCoordinate?) {
        
        let graph = self.visibleGraph
        
        // When adding multiple `layer-input`s to the canvas at the same time,
        // offset them vertically
        var canvasHeightOffset = 0
        
        let addLayerInput = { (nodeId: NodeId) in
            guard let node = graph.getNode(nodeId) else {
                fatalErrorIfDebug("handleLayerInputAdded: could not add Layer Input to graph")
                return
            }
            self.layerInputAddedToGraph(node: node,
                                        layerInput: layerInput,
                                        draggedOutput: draggedOutput,
                                        canvasHeightOffset: canvasHeightOffset)
            canvasHeightOffset += 1
        }
                
        let inspectorFocusedLayers = graph.inspectorFocusedLayers
        
        if inspectorFocusedLayers.count > 1 {
            
            // TODO: what happens if e.g. Size Input is common to both Oval and Rectangle, but Oval's Height Field has been blocked out (because its SizingScenario Input is non-auto) ?
            
            // TODO: can we just iterate through all primarily-selected layers?
            
            if let multiselectInputs: Set<LayerInputPort> = graph.propertySidebar.inputsCommonToSelectedLayers,
               
                let layerMultiselectInput: LayerInputPort = multiselectInputs.first(where: { $0 == layerInput}) {
               
                layerMultiselectInput.multiselectObservers(graph).forEach { (observer: LayerInputObserver) in
                    // Note: we cannot add "whole input" to canvas if one field is already on canvas
                    if let packedRow = observer.packedRowObserverOnlyIfPacked {
                        addLayerInput(packedRow.id.nodeId)
                    }
                }
            }
            
        } else if let focusedLayer = inspectorFocusedLayers.first {
            // TODO: shouldn't we also check whether this input already has a field on the canvas? Currently this possibility is probably prevented in the UI itself; can we consolidate the logic/rule somewhere?
            addLayerInput(focusedLayer.asLayerNodeId.asNodeId)
        }
    }
}

extension GraphState {
    // Only used when a layer node's input or input-field added to the canvas
    @MainActor
    func resetLayerInputsCache(layerNode: LayerNodeViewModel,
                               activeIndex: ActiveIndex) {
        layerNode.resetInputCanvasItemsCache(graph: self,
                                             activeIndex: activeIndex)

        // Reset graph cache to get new nodes to appear
        // Dispatch needed for fix
        DispatchQueue.main.async { [weak self] in
            self?.visibleNodesViewModel.resetVisibleCanvasItemsCache()
        }
    }
}

// TODO:
extension CGFloat {
    // TODO: needs to be wider, for e.g. whole padding input
    static let layerInputAssumedCanvasWidth: Self = 400
    
    // TODO: needs to be smaller?
    static let layerFieldAssumedCanvasWidth: Self = 120
    
    static let layerInputOrFieldAssumedCanvasHeight: Self = 160
}

extension StitchDocumentViewModel {

    // TODO: really, "position (added via LLM)" and "dragged output (added via edge-drawing)" are mutually exclusive
    @MainActor
    func getLayerInputOrFieldCanvasInsertionPosition(draggedOutput: OutputCoordinate?,
                                                     canvasHeightOffset: Int?,
                                                     position: CGPoint?) -> CGPoint {
                
        let yOffset = CGFloat(canvasHeightOffset ?? 0) * .layerInputAssumedCanvasWidth
        
        if let positionFromLLM = position {
            return positionFromLLM
        }
        
        if let draggedOutput = draggedOutput,
           // The canvas item for the dragged output, NOT the canvas item for the added-input
           let canvasItemForDraggedOutput = self.visibleGraph.getCanvasItem(outputId: draggedOutput),
           let outputIndex = draggedOutput.portId,
           let outputRowViewModel = canvasItemForDraggedOutput.outputViewModels[safe: outputIndex],
           var outputAnchorPoint = outputRowViewModel.portUIViewModel.anchorPoint {
            
            outputAnchorPoint.y += yOffset
            
            // TODO: how to know the size of the canvas item *for the layer input being added* ? We will not have read the size of the canvas item since it is not yet on the canvas
            outputAnchorPoint.x += .layerInputAssumedCanvasWidth
            
            return outputAnchorPoint
        }
        
        // Otherwise fall back on center-placement
        var defaultInsertionPosition = self.newCanvasItemInsertionLocation
        defaultInsertionPosition.y += yOffset
        return defaultInsertionPosition
    }
    
    @MainActor
    func layerInputAddedToGraph(node: NodeViewModel,
                                layerInput: LayerInputPort,
                                
                                // We added a layer-input to the canvas via edge-drawing,
                                // and need to position the layer-input next to the dragged output.
                                draggedOutput: OutputCoordinate?,
                                
                                // If we added multiple layer inputs to the canvas at one time (via layer multiselect), we offset them
                                canvasHeightOffset: Int?,
                                
                                // For LLM-actions, horizontal offset
                                position: CGPoint? = nil) {
        
        let nodeId = node.id
        
        let graph = self.visibleGraph
        
        guard let layerNode = graph.getLayerNode(nodeId) else {
            fatalErrorIfDebug()
            return
        }
        
        guard layerNode[keyPath: layerInput.layerNodeKeyPath].mode == .packed else {
            log("Tried to add whole layer input to canvas when layer input was in unpack mode")
            return
        }
        
        let input: InputLayerNodeRowData = layerNode[keyPath: layerInput.packedLayerInputKeyPath]
        
        // If already on this canvas, do nothing
        // (Can happen from dragging an edge onto the inspector)
        guard !input.canvasObserver.isDefined else {
            log("Input already on canvas")
            return
        }
        
        let canvasItemId: CanvasItemId = .layerInput(LayerInputCoordinate(
            node: nodeId,
            keyPath: .init(layerInput: layerInput, portType: .packed)))
        
        let canvasPosition = self.getLayerInputOrFieldCanvasInsertionPosition(
            draggedOutput: draggedOutput,
            canvasHeightOffset: canvasHeightOffset,
            position: position)
        
        let canvasItem = CanvasItemViewModel(
            id: canvasItemId,
            position: canvasPosition,
            zIndex: graph.highestZIndex + 1,
            // Put newly-created LIG into graph's current traversal level
            parentGroupNodeId: self.groupNodeFocused?.asNodeId,
            inputRowObservers: [input.rowObserver],
            outputRowObservers: [])
        
        canvasItem.assignNodeReferenceAndUpdateFieldGroupsOnRowViewModels(
            node,
            activeIndex: self.activeIndex,
            // When adding an entire input to the graph, we don't worry about unpacked state etc.
            unpackedPortParentFieldGroupType: nil,
            unpackedPortIndex: nil,
            graph: graph)
        
        
        // If we added this layer input to the canvas as part of an edge-drag,
        // create an
        if let draggedOutput = draggedOutput {
            guard let firstInput = canvasItem.inputViewModels.first?.nodeIOCoordinate else {
                fatalErrorIfDebug()
                return
            }
            graph.addEdgeWithoutGraphRecalc(from: draggedOutput, to: firstInput)
        }
        
        
        input.canvasObserver = canvasItem
        
        // Subscribe inspector row ui data to the row data's canvas item
        input.inspectorRowViewModel.canvasItemDelegate = input.canvasObserver
        
        // TODO: why do we have to do this?
        if let layerNode = node.layerNode {
            graph.resetLayerInputsCache(layerNode: layerNode,
                                        activeIndex: self.activeIndex)
        }
        
        graph.propertySidebar.selectedProperty = nil
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
