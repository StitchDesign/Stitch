//
//  OutputNodeRowObserver.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/4/25.
//

import Foundation
import StitchSchemaKit


@Observable
final class OutputNodeRowObserver: NodeRowObserver {
    
    static let nodeIOType: NodeIO = .output
    let containsUpstreamConnection = false  // always false

    // TODO: Outputs can only use portIds, so this should be something more specific than NodeIOCoordinate
    let id: NodeIOCoordinate
    
    // Data-side for values
    @MainActor var allLoopedValues: PortValues = .init()
    
    // NodeRowObserver holds a reference to its parent, the Node
    @MainActor weak var nodeDelegate: NodeViewModel?
    
    // MARK: "derived data", cached for UI perf
        
    // Only for outputs, designed for port edge color usage
    @MainActor var containsDownstreamConnection = false
    
    // Can't be computed for rendering purposes
    @MainActor var hasLoopedValues: Bool = false
    
    @MainActor
    var hasEdge: Bool {
        self.containsDownstreamConnection
    }
    
    @MainActor
    init(values: PortValues,
         id: NodeIOCoordinate,
         // always nil but needed for protocol
         upstreamOutputCoordinate: NodeIOCoordinate? = nil) {
        
        assertInDebug(upstreamOutputCoordinate == nil)
        
        self.id = id
        self.allLoopedValues = values
        self.hasLoopedValues = values.hasLoop
    }

    // Implements StitchEngine protocol
    func updateOutputValues(_ values: [PortValue]) {
        guard let graph = self.nodeDelegate?.graphDelegate else {
            fatalErrorIfDebug()
            return
        }
        self.updateValuesInOutput(values, graph: graph)
    }
}

@MainActor
func updateRowObservers(rowObservers: [OutputNodeRowObserver],
                        newIOValues: PortValuesList) {
    
    newIOValues.enumerated().forEach { portId, newValues in
        guard let observer = rowObservers[safe: portId] else {
            log("Could not retrieve output observer for portId \(portId)")
            return
        }
        
        observer.updateOutputValues(newValues)
    }
}

extension OutputNodeRowObserver {
    @MainActor
    func updateValuesInOutput(_ newValues: PortValues, graph: GraphState) {
        self.setValuesInRowObserver(newValues,
                                    selectedEdges: graph.selectedEdges,
                                    selectedCanvasItems: graph.selection.selectedCanvasItems,
                                    drawingObserver: graph.edgeDrawingObserver)
        self.outputPostProcessing(graph)
    }
    
 
    // Note: this returns quite different results depending on whether the owner-node is e.g. a patch vs a group
    @MainActor var allRowViewModels: [OutputNodeRowViewModel] {
        guard let node = self.nodeDelegate,
              let graph = node.graphDelegate else {
            return []
        }
        return getOutputRowViewModels(id: self.id, nodeType: node.nodeType, graph: graph)
    }
        
    @MainActor
    func getDownstreamCanvasItemsIds() -> Set<CanvasItemId> {
        guard let graph = self.nodeDelegate?.graphDelegate,
              let downstreamConnections: Set<InputCoordinate> = graph.connections.get(self.id) else {
            return .init()
        }
        
        return downstreamConnections.reduce(into: CanvasItemIdSet()) { partialResult, inputId in
            
            if let canvasItem = graph.getCanvasItem(inputId: inputId) {
                partialResult.insert(canvasItem.id)
                
                // If the downstream canvas item is a group input splitter,
                // we need to also add the group's own canvas item id
                if graph.getNode(canvasItem.id.nodeId)?.splitterType == .input,
                   let groupNodeCanvasId = canvasItem.parentGroupNodeId.flatMap({ graph.getGroupNode($0) })?.id {
                    partialResult.insert(groupNodeCanvasId)
                }
            }
        }
    }
    
    @MainActor func getDownstreamInputsObservers() -> [InputNodeRowObserver] {
        guard let graph = self.nodeDelegate?.graphDelegate else {
            fatalErrorIfDebug() // should have had graph state
            return .init()
        }
        return graph.connections.get(self.id)?
            .compactMap { graph.getInputRowObserver($0) }
        ?? .init()
    }
}


// "Pure" form for retrieving output row view models
@MainActor
func getOutputRowViewModels(id: OutputCoordinate,
                            nodeType: NodeViewModelType,
                            graph: GraphReader) -> [OutputNodeRowViewModel] {
    
    switch nodeType {
        
    case .patch(let patchNode):
        guard let portId = id.portId,
              let patchOutput = patchNode.canvasObserver.outputViewModels[safe: portId] else {
            fatalErrorIfDebug()
            return []
        }
        
        var outputs = [patchOutput]
        
        // Find row view models for group if applicable
        if patchNode.splitterNode?.type == .output {
            // Group id is the only other row view model's canvas's parent ID
            if let groupNodeId = outputs.first?.canvasItemDelegate?.parentGroupNodeId,
               let groupNode: CanvasItemViewModel = graph.getNode(groupNodeId)?.nodeType.groupNode {
                outputs += groupNode.outputViewModels.filter {
                    $0.rowDelegate?.id == id
                }
            }
        }
        return outputs
        
    case .layer(let layerNode):
        guard let portId = id.portId,
              let port = layerNode.outputPorts[safe: portId] else {
            fatalErrorIfDebug()
            return []
        }
        var outputs = [port.inspectorRowViewModel]
        if let canvasOutput = port.canvasObserver?.outputViewModels.first {
            outputs.append(canvasOutput)
        }
        return outputs
        
    case .group(let canvas):
        guard let portId = id.portId,
              let groupOutput = canvas.outputViewModels[safe: portId] else {
            fatalErrorIfDebug()
            return []
        }
        return [groupOutput]
        
    case .component(let component):
        let canvas = component.canvas
        guard let portId = id.portId,
              let groupOutput = canvas.outputViewModels[safe: portId] else {
            fatalErrorIfDebug()
            return []
        }
        
        return [groupOutput]
    }
}
