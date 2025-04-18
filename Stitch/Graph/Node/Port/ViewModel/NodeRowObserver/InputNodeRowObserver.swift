//
//  InputNodeRowObserver.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/4/25.
//

import Foundation
import StitchSchemaKit
import StitchEngine


@Observable
final class InputNodeRowObserver: NodeRowObserver, InputNodeRowCalculatable {
    static let nodeIOType: NodeIO = .input

    let id: NodeIOCoordinate
    
    // Data-side for values
    @MainActor
    var allLoopedValues: PortValues = .init()

    // Connected upstream node, if input
    @MainActor
    var upstreamOutputCoordinate: NodeIOCoordinate? {
        didSet(oldValue) {
            self.didUpstreamOutputCoordinateUpdate(oldValue: oldValue)
        }
    }
    
    /// Tracks upstream output row observer for some input. Cached for perf.
    @MainActor
    var upstreamOutputObserver: OutputNodeRowObserver? {
        guard let graph = self.nodeDelegate?.graphDelegate else {
            return nil
        }
        return self.getUpstreamOutputObserver(graph: graph)
    }
    
    // NodeRowObserver holds a reference to its parent, the Node
    @MainActor weak var nodeDelegate: NodeViewModel?

    // MARK: "derived data", cached for UI perf
        
    // Can't be computed for rendering purposes
    @MainActor var hasLoopedValues: Bool = false
    
    @MainActor
    var hasEdge: Bool {
        self.upstreamOutputCoordinate.isDefined
    }
    
    @MainActor
    convenience init(from schema: NodePortInputEntity) {
        self.init(values: schema.portData.values ?? [],
                  id: schema.id,
                  upstreamOutputCoordinate: schema.portData.upstreamConnection)
    }
    
    @MainActor
    init(values: PortValues,
         id: NodeIOCoordinate,
         upstreamOutputCoordinate: NodeIOCoordinate?) {
        self.id = id
        self.upstreamOutputCoordinate = upstreamOutputCoordinate
        self.allLoopedValues = values
        self.hasLoopedValues = values.hasLoop
    }
        
    func updateOutputValues(_ values: [PortValue]) {
        fatalErrorIfDebug("Should never be called for InputNodeRowObserver")
    }
    
    @MainActor
    var isPulseNodeType: Bool {
        self.allLoopedValues.first?.getPulse.isDefined ?? false
    }
}

extension InputNodeRowObserver {
    
    // Used in Stitch when updating an input's values
    // Note: cannot be used in `StitchEngine` until SE no longer already updates `self.values = incomingValues`
    @MainActor
    func updateValuesInInput(_ incomingValues: PortValues,
                             // Always true excerpt for node-type-change
                             shouldCoerceToExistingInputType: Bool = true,
                             // TODO: remove once StitchEngine.setValuesInInput no longer already does `self.values = values`
                             passedDownOldValues: PortValues? = nil) {
        
        /*
         In some cases (e.g. graph initialization, schema deserialization?),
         we set values in an input *before* node/graph delegates have been assigned to the input.
         
         In such cases, we assume the incoming value is the correct type and set them directly.
         */
        // TODO: Pass down NodeViewModel and `currentGraphTime` directly? Greater referential transparency and avoids confusion about where/when delegates have been set / not yet set.
                
        guard let node = self.nodeDelegate,
              let graph = node.graphDelegate else {
            self.setValuesInRowObserver(incomingValues,
                                        selectedEdges: .init(),
                                        selectedCanvasItems: .init(),
                                        drawingObserver: .init())
            return
        }

        let oldValues = passedDownOldValues ?? self.values
        
        // Can an input's `oldValues` ever be empty?
        guard let inputType: PortValue = oldValues.first ?? node.userVisibleType?.defaultPortValue else {
            return
        }
        
        var newValues = incomingValues
        if shouldCoerceToExistingInputType {
            newValues = self.coerce(theseValues: incomingValues,
                                    toThisType: inputType,
                                    currentGraphTime: graph.currentGraphTime)
        }
        
        // Set the coerced values in the input
        self.setValuesInRowObserver(newValues,
                                    selectedEdges: graph.selectedEdges,
                                    selectedCanvasItems: graph.selection.selectedCanvasItems,
                                    drawingObserver: graph.edgeDrawingObserver)
        
        // Update other parts of graph state in response to input change
        self.inputPostProcessing(oldValues: oldValues,
                                 newValues: newValues,
                                 graph: graph)
    }
    
    // ONLY called by StitchEngine
    // Note: technically, the values passed in here are already coerced by StitchEngine
    @MainActor
    func didInputsUpdate(newValues: PortValues,
                         oldValues: PortValues) {
        
        // If newValues empty, nothing to do
        // Note: this only happens when graph is first opened and connected inputs receive empty outputs?
        guard !newValues.isEmpty else {
            return
        }
                        
        self.updateValuesInInput(newValues,
                                 // Must still pass oldValues when called from StitchEngine,
                                 // like this function is
                                 passedDownOldValues: oldValues)
    }
    
    @MainActor
    func didUpstreamOutputCoordinateUpdate(oldValue: NodeIOCoordinate?) {
        let coordinateValueChanged = oldValue != self.upstreamOutputCoordinate
        
        guard let _ = self.upstreamOutputCoordinate else {
            if let oldUpstreamObserver = self.upstreamOutputObserver {
                log("upstreamOutputCoordinate: removing edge")
                
                // Remove edge data
                oldUpstreamObserver.containsDownstreamConnection = false
            }
            
            if coordinateValueChanged {
                // Flatten values
                let newFlattenedValues = self.allLoopedValues.flattenValues()
                self.updateValuesInInput(newFlattenedValues)

                // Recalculate node once values update
                self.nodeDelegate?.scheduleForNextGraphStep()
            }
            
            return
        }
        
        // Update that upstream observer of new edge
        self.upstreamOutputObserver?.containsDownstreamConnection = true
    }
    
    // Because `private`, needs to be declared in same file(?) as method that uses it
    @MainActor
    private func getUpstreamOutputObserver(graph: GraphReader) -> OutputNodeRowObserver? {
        guard let upstreamCoordinate = self.upstreamOutputCoordinate,
              let upstreamPortId = upstreamCoordinate.portId else {
            return nil
        }

        // Set current upstream observer
        return graph.getNode(upstreamCoordinate.nodeId)?.getOutputRowObserver(for: upstreamPortId)
    }
        
    @MainActor var allRowViewModels: [InputNodeRowViewModel] {
        guard let node = self.nodeDelegate,
              let graph = node.graphDelegate else {
            return []
        }
                
        switch node.nodeType {
            
        case .patch(let patchNode):
            guard let portId = self.id.portId,
                  let patchInput = patchNode.canvasObserver.inputViewModels[safe: portId] else {
                // MathExpression is allowed to have empty inputs
                #if DEV_DEBUG || DEBUG
                if patchNode.patch != .mathExpression {
                    fatalErrorIfDebug()
                }
                #endif
                return []
            }
            
            var inputs = [patchInput]
            
            // Find row view models for group if applicable
            if patchNode.splitterNode?.type == .input {
                // Group id is the only other row view model's canvas's parent ID
                if let groupNodeId = inputs.first?.canvasItemDelegate?.parentGroupNodeId,
                   let groupNode: CanvasItemViewModel = graph.getNode(groupNodeId)?.nodeType.groupNode {
                    inputs += groupNode.inputViewModels.filter {
                        $0.rowDelegate?.id == self.id
                    }
                }
            }
            return inputs
            
        case .layer(let layerNode):
            guard let keyPath = id.keyPath else {
                fatalErrorIfDebug()
                return []
            }
            let layerInputRowData: InputLayerNodeRowData = layerNode[keyPath: keyPath.layerNodeKeyPath]
            var inputs = [layerInputRowData.inspectorRowViewModel]
            if let canvasInput = layerInputRowData.canvasObserver?.inputViewModels.first {
                inputs.append(canvasInput)
            }
            return inputs
            
        case .group(let canvas):
            guard let portId = self.id.portId,
                  let groupInput = canvas.inputViewModels[safe: portId] else {
                fatalErrorIfDebug()
                return []
            }
            return [groupInput]
            
        case .component(let component):
            let canvas = component.canvas
            guard let portId = self.id.portId,
                  let groupInput = canvas.inputViewModels[safe: portId] else {
                fatalErrorIfDebug()
                return []
            }
            return [groupInput]
        }
    }
    
    @MainActor
    func buildUpstreamReference() {
        guard let connectedOutputObserver = self.upstreamOutputObserver else {
            // Upstream values are cached and need to be refreshed if disconnected
            if self.upstreamOutputCoordinate != nil {
                self.upstreamOutputCoordinate = nil
            }
            
            return
        }

        //        // Check for connected row observer rather than just setting ID--makes for
        //        // a more robust check in ensuring the connection actually exists
        //        assertInDebug(
        //            connectedOutputObserver.id.portId.flatMap { portId in
        //                self.nodeDelegate?
        //                    .graphDelegate?
        //                // Note: we have to retrieve the node for the upstream output
        //                    .getNode(connectedOutputObserver.id.nodeId)?
        //                    .getOutputRowObserver(for: portId)
        //            }.isDefined
        //        )
        
        // Report to output observer that there's an edge (for port colors)
        // We set this to false on default above
        connectedOutputObserver.containsDownstreamConnection = true
    }
}

extension [InputNodeRowObserver] {
    @MainActor
    init(values: PortValuesList,
         id: NodeId,
         nodeIO: NodeIO,
         nodeDelegate: NodeViewModel,
         graph: GraphState) {
        self = values.enumerated().map { portId, values in
            Element(values: values,
                    id: NodeIOCoordinate(portId: portId, nodeId: id),
                    upstreamOutputCoordinate: nil,
                    nodeDelegate: nodeDelegate,
                    graph: graph)
        }
    }
}
