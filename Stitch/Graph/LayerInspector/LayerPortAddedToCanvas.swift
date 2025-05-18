//
//  LayerPortAddedToCanvas.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/15/25.
//

import Foundation
import SwiftUI


extension CGFloat {
    // TODO: needs to be wider, for e.g. whole padding input
    static let layerInputAssumedCanvasWidth: Self = 400
    
    // TODO: needs to be smaller?
    static let layerFieldAssumedCanvasWidth: Self = 120
    
    static let layerInputOrFieldAssumedCanvasHeight: Self = 120
}

extension StitchDocumentViewModel {
    // TODO: really, "position (added via LLM)" and "dragged output (added via edge-drawing)" are mutually exclusive
    @MainActor
    func getLayerInputOrFieldCanvasInsertionPosition(draggedOutput: OutputPortUIViewModel?,
                                                     canvasHeightOffset: Int?,
                                                     position: CGPoint?) -> CGPoint {
        
        let yOffset = CGFloat(canvasHeightOffset ?? 0) * .layerInputOrFieldAssumedCanvasHeight
        
        if let positionFromLLM = position {
            return positionFromLLM
        }
        
        if var draggedOutputAnchorPoint = draggedOutput?.anchorPoint {
            // The canvas item for the dragged output, NOT the canvas item for the added-input
            //           let canvasItemForDraggedOutput = self.visibleGraph.getCanvasItem(outputId: draggedOutput),
            //           let outputIndex = draggedOutput.portId,
            //           let outputRowViewModel = canvasItemForDraggedOutput.outputViewModels[safe: outputIndex],
            
            //           var outputAnchorPoint = outputRowViewModel.portUIViewModel.anchorPoint {
            //           var draggedOutputAnchorPoint = draggedOutput.anchorPoint {
            
            draggedOutputAnchorPoint.y += yOffset
            
            // TODO: how to know the size of the canvas item *for the layer input being added* ? We will not have read the size of the canvas item since it is not yet on the canvas
            draggedOutputAnchorPoint.x += .layerInputAssumedCanvasWidth
            
            return draggedOutputAnchorPoint
        }
        
        // Otherwise fall back on center-placement
        var defaultInsertionPosition = self.newCanvasItemInsertionLocation
        defaultInsertionPosition.y += yOffset
        return defaultInsertionPosition
    }
}


// MARK: whole input added to canvas

struct LayerInputAddedToCanvas: StitchDocumentEvent {
    
    let layerInput: LayerInputPort
    
    func handle(state: StitchDocumentViewModel) {
        state.handleLayerInputAdded(layerInput: layerInput, draggedOutput: nil)
        state.encodeProjectInBackground()
    }
}

extension StitchDocumentViewModel {
    
    @MainActor
    func handleLayerInputAdded(layerInput: LayerInputPort,
                               // non-nil just when we dragged an edge over
                               draggedOutput: OutputPortUIViewModel?) {
        
        let graph = self.visibleGraph
        
        // When adding multiple `layer-input`s to the canvas at the same time,
        // offset them vertically
        var canvasHeightOffset = 0
        
        let addLayerInput = { (nodeId: NodeId) in
            guard let node = graph.getNode(nodeId) else {
                fatalErrorIfDebug("handleLayerInputAdded: could not add Layer Input to graph")
                return
            }
            self.addLayerInputToCanvas(node: node,
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


extension StitchDocumentViewModel {
    @MainActor
    func addLayerInputToCanvas(node: NodeViewModel,
                               layerInput: LayerInputPort,
                               
                               // We added a layer-input to the canvas via edge-drawing,
                               // and need to position the layer-input next to the dragged output.
                               draggedOutput: OutputPortUIViewModel?,
                               
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
            log("Layer Input \(layerInput) already on canvas")
            return
        }
        
        let canvasPosition = self.getLayerInputOrFieldCanvasInsertionPosition(
            draggedOutput: draggedOutput,
            canvasHeightOffset: canvasHeightOffset,
            position: position)
        
        let canvasItem = CanvasItemViewModel(
            id: .layerInput(LayerInputCoordinate(
                node: nodeId,
                keyPath: .init(layerInput: layerInput, portType: .packed))),
            position: canvasPosition,
            zIndex: graph.highestZIndex + 1,
            // Put newly-created LIG into graph's current traversal level
            parentGroupNodeId: self.groupNodeFocused?.asNodeId,
            inputRowObservers: [input.rowObserver],
            outputRowObservers: [])
        
        let activeIndex = self.activeIndex
        
        canvasItem.assignNodeReferenceAndUpdateFieldGroupsOnRowViewModels(
            node,
            activeIndex: activeIndex,
            // When adding an entire input to the graph, we don't worry about unpacked state etc.
            unpackedPortParentFieldGroupType: nil,
            unpackedPortIndex: nil,
            graph: graph)
        
        self.createEdgeIfLayerInputOrFieldAddedViaOutputDrag(
            draggedOutput: draggedOutput?.id,
            layerInputOrFieldCanvasItem: canvasItem)
        
        input.canvasObserver = canvasItem
        
        // Subscribe inspector row ui data to the row data's canvas item
        input.inspectorRowViewModel.canvasItemDelegate = input.canvasObserver
        
        // TODO: why do we have to do this?
        if let layerNode = node.layerNode {
            graph.resetLayerInputsCache(layerNode: layerNode,
                                        activeIndex: activeIndex)
        }
        
        graph.propertySidebar.selectedProperty = nil
    }
    
    // If we added this layer-input to the canvas as part of an edge-drag,
    // create an edge between the dragged output and the added layer-input
    @MainActor
    func createEdgeIfLayerInputOrFieldAddedViaOutputDrag(draggedOutput: OutputCoordinate?,
                                                         layerInputOrFieldCanvasItem: CanvasItemViewModel) {
        
        // If we added this layer-input to the canvas as part of an edge-drag,
        // create an edge between the dragged output and the added layer-input
        if let draggedOutput = draggedOutput {
            guard let firstInput = layerInputOrFieldCanvasItem.inputViewModels.first?.nodeIOCoordinate else {
                fatalErrorIfDebug()
                return
            }
            self.visibleGraph.addEdgeWithoutGraphRecalc(from: draggedOutput, to: firstInput)
        }
    }
}



// MARK: layer input-field added to canvas

struct LayerInputFieldAddedToCanvas: StitchDocumentEvent {
    
    let layerInput: LayerInputPort
    let fieldIndex: Int
    
    @MainActor
    func handle(state: StitchDocumentViewModel) {
        state.handleLayerInputFieldAddedToCanvas(
            layerInput: layerInput,
            fieldIndex: fieldIndex,
            draggedOutput: nil)
    }
}


extension StitchDocumentViewModel {
    @MainActor
    func addLayerFieldToCanvas(layerInput: LayerInputPort,
                               nodeId: NodeId,
                               fieldIndex: Int,
                               // We added a layer-input to the canvas via edge-drawing,
                               // and need to position the layer-input next to the dragged output.
                               draggedOutput: OutputPortUIViewModel?,
                               
                               // If we added multiple layer inputs to the canvas at one time (via layer multiselect), we offset them
                               canvasHeightOffset: Int?) {
        
        let graph = self.visibleGraph
        
        guard let node = graph.getNode(nodeId),
              let layerNode = node.layerNode else {
            fatalErrorIfDebug("LayerInputFieldAddedToCanvas: no node and/or layer node")
            return
        }
        
        let portObserver: LayerInputObserver = layerNode[keyPath: layerInput.layerNodeKeyPath]
        
        let previousPackMode = portObserver.mode
        
        guard let unpackedPort: InputLayerNodeRowData = portObserver._unpackedData.allPorts[safe: fieldIndex] else {
            fatalErrorIfDebug("LayerInputFieldAddedToCanvas: no unpacked port for fieldIndex \(fieldIndex)")
            return
        }
        
        guard !unpackedPort.canvasObserver.isDefined else {
            log("addLayerFieldToCanvas: Field \(fieldIndex) for input \(layerInput) already on canvas")
            return
        }
    
        // MARK: CREATING AND INITIALIZING THE CANVAS ITEM VIEW MODEL ITSELF
        
        // First field-group grabbed since layers don't have differing groups within one input
        guard let unpackedPortParentFieldGroupType: FieldGroupType = layerInput
            .getDefaultValue(for: layerNode.layer)
            .getNodeRowType(nodeIO: .input, layerInputPort: layerInput, isLayerInspector: true)
            .fieldGroupTypes
            .first else {
            fatalErrorIfDebug()
            return
        }
        
        let activeIndex = self.activeIndex
        
        let canvasPosition = self.getLayerInputOrFieldCanvasInsertionPosition(
            draggedOutput: draggedOutput,
            canvasHeightOffset: canvasHeightOffset,
            position: nil)
        
        let canvasItem = CanvasItemViewModel(
            id: .layerInput(LayerInputCoordinate(node: nodeId,
                                                 keyPath: unpackedPort.id)),
            position: canvasPosition,
            zIndex: graph.highestZIndex + 1,
            parentGroupNodeId: self.groupNodeFocused?.groupNodeId,
            inputRowObservers: [unpackedPort.rowObserver],
            outputRowObservers: [])
        
        canvasItem.assignNodeReferenceAndUpdateFieldGroupsOnRowViewModels(
            node,
            activeIndex: activeIndex,
            unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
            unpackedPortIndex: fieldIndex,
            graph: graph)
        
        self.createEdgeIfLayerInputOrFieldAddedViaOutputDrag(
            draggedOutput: draggedOutput?.id,
            layerInputOrFieldCanvasItem: canvasItem)
        
        unpackedPort.canvasObserver = canvasItem
        
        // MARK: Change the pack mode
        
        let newPackMode = portObserver.mode
        if previousPackMode != newPackMode {
            portObserver.wasPackModeToggled(document: self)
        }
        
        // MARK: RESET CACHE
        
        graph.resetLayerInputsCache(layerNode: layerNode,
                                    activeIndex: activeIndex) // Why?
    }
    
    @MainActor
    func handleLayerInputFieldAddedToCanvas(layerInput: LayerInputPort,
                                            fieldIndex: Int,
                                            // non-nil just when we dragged an edge over
                                            draggedOutput: OutputPortUIViewModel?) {
        let graph = self.visibleGraph
        
        // When adding multiple `layer-input-fields`s to the canvas at the same time,
        // offset them vertically
        var canvasHeightOffset = 0
        
        let addLayerField = { (nodeId: NodeId) in
            self.addLayerFieldToCanvas(layerInput: layerInput,
                                       nodeId: nodeId,
                                       fieldIndex: fieldIndex,
                                       draggedOutput: draggedOutput,
                                       canvasHeightOffset: canvasHeightOffset)
            canvasHeightOffset += 1
        }
        
        let inspectorFocusedLayers = graph.inspectorFocusedLayers
        
        if inspectorFocusedLayers.count > 1 {
            if let multiselectInputs = graph.propertySidebar.inputsCommonToSelectedLayers,
               let layerMultiselectInput = multiselectInputs.first(where: { $0 == layerInput}) {
                layerMultiselectInput.multiselectObservers(graph).forEach { (observer: LayerInputObserver) in
                    addLayerField(observer.nodeId)
                }
            }
        } else if let focusedLayer = inspectorFocusedLayers.first {
            addLayerField(focusedLayer.asLayerNodeId.asNodeId)
        }
        
        self.encodeProjectInBackground()
    }
}



// MARK: layer output added to canvas

struct LayerOutputAddedToCanvas: StitchDocumentEvent {
    
    let nodeId: NodeId
    let portId: Int
    
    func handle(state: StitchDocumentViewModel) {
        
        // log("LayerOutputAddedToCanvas: nodeId: \(nodeId)")
        // log("LayerOutputAddedToCanvas: coordinate: \(coordinate)")
        let graph = state.visibleGraph
        
        guard let node = graph.getNode(nodeId),
              let layerNode = node.layerNode,
              let outputPort = layerNode.outputPorts[safe: portId] else {
            fatalErrorIfDebug("LayerOutputAddedToCanvas: could not add Layer Output to graph")
            return
        }
        
        graph.layerOutputAddedToCanvas(node: node,
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
    func layerOutputAddedToCanvas(node: NodeViewModel,
                                  output: OutputLayerNodeRowData,
                                  activeIndex: ActiveIndex,
                                  portId: Int,
                                  groupNodeFocused: NodeId?,
                                  insertionLocation: CGPoint) {
        
        output.canvasObserver = CanvasItemViewModel(
            id: .layerOutput(.init(node: node.id,
                                   portId: portId)),
            position: insertionLocation,
            zIndex: self.highestZIndex + 1,
            // Put newly-created LIG into graph's current traversal level
            parentGroupNodeId: groupNodeFocused,
            inputRowObservers: [],
            outputRowObservers: [output.rowObserver])
        
        output.canvasObserver?.assignNodeReferenceAndUpdateFieldGroupsOnRowViewModels(
            node,
            activeIndex: activeIndex,
            // Not relevant for output
            unpackedPortParentFieldGroupType: nil,
            unpackedPortIndex: nil,
            graph: self)
        
        // Subscribe inspector row ui data to the row data's canvas item
        output.inspectorRowViewModel.canvasItemDelegate = output.canvasObserver
        
        self.propertySidebar.selectedProperty = nil
    }
}
