//
//  PortDragActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/19/22.
//

import SwiftUI
import StitchSchemaKit


extension GraphState {
    // really we're just: retrieving row observer, retrieving node, updating edge-drawing-observer's nearest eligible input, scheduling the node to run for next graph step, encoding the project
    @MainActor
    func inputDragged(gesture: DragGesture.Value,
                      rowId: NodeRowViewModelId) {
        
        guard let inputRowViewModel = self.getInputRowViewModel(for: rowId),
              let inputRowObserver = self.getInputRowObserver(inputRowViewModel.nodeIOCoordinate),
              let node = self.getNode(inputRowViewModel.id.nodeId) else {
            fatalErrorIfDebug()
            return
        }
        
        var dragLocation = gesture.location
        let graphOrigin = self.graphPosition
        dragLocation.x -= graphOrigin.x
        dragLocation.y -= graphOrigin.y
        
        self.edgeAnimationEnabled = true
        
        // If we already have an active input-drag:
        if let existingDrawingGesture = self.edgeDrawingObserver.drawingGesture {
            // Called when drag has already started
            existingDrawingGesture.cursorLocationInGlobalCoordinateSpace = dragLocation
        }
        
        // Else, if we're starting a new input-drag:
        else {
            guard let upstreamObserver = inputRowObserver.upstreamOutputObserver?.rowViewModelForCanvasItemAtThisTraversalLevel else {
                return
            }
            
            self.edgeDrawingObserver.nearestEligibleEdgeDestination = .canvasInput(inputRowViewModel)

            self.edgeDrawingObserver.drawingGesture = OutputDragGesture(
                outputId: upstreamObserver.id,
                cursorLocationInGlobalCoordinateSpace: dragLocation,
                startingDiffFromCenter: .zero)

            inputRowObserver.removeUpstreamConnection(node: node)
            node.scheduleForNextGraphStep()
            self.encodeProjectInBackground()
        }
    }
    
    @MainActor
    func inputDragEnded() {
        guard let document = documentDelegate else {
            return
        }
        
        if let drawingGesture = self.edgeDrawingObserver.drawingGesture,
           let fromRowObserver = self.getOutputRowObserver(drawingGesture.outputId.asNodeIOCoordinate),
           let nearestEligible = self.edgeDrawingObserver.nearestEligibleEdgeDestination,
           let dragOriginOutput = self.getOutputRowViewModel(for: drawingGesture.outputId) {
            
            self.createEdgeAfterPortDragEnded(
                nearestEligibleDestination: nearestEligible,
                sourceNodeId: fromRowObserver.id.nodeId,
                dragOriginOutput: dragOriginOutput,
                document: document)

            self.edgeDrawingObserver.reset()
            self.encodeProjectInBackground()
            return
        }
        
        // No eligible input
        else {
            // log("InputDragEnded: drag ended, but could not create new edge")
            self.edgeDrawingObserver.reset()
            DispatchQueue.main.async { [weak self] in
                self?.edgeAnimationEnabled = false
            }
            return
        }
       
    }
}

extension OutputNodeRowViewModel {
    static func calculateDiffFromCenter(from gesture: DragGesture.Value) -> CGSize {
        let startX = gesture.startLocation.x
        let startY = gesture.startLocation.y

        let xDistanceFromLocalCenter = startX.magnitude
        let yDistanceFromLocalCenter = startY.magnitude

        let localCenterDistanceFromAnchorCenterX = PORT_ENTRY_NON_EXTENDED_HITBOX_SIZE.width/2
        let localCenterDistanceFromAnchorCenterY = PORT_ENTRY_NON_EXTENDED_HITBOX_SIZE.height/2

        let totalDistanceX = xDistanceFromLocalCenter + localCenterDistanceFromAnchorCenterX
        let totalDistanceY = yDistanceFromLocalCenter + localCenterDistanceFromAnchorCenterY

        var diffFromCenter = CGSize()

        /*
         Some of these numbers are eye-balled.

         There's a more complex trig/geometry relationship here:
         - The local coordinate space has its origin in the top left corner of the non-extended (blue debug border) hitbox,
         - ... but a drag could start anywhere in the extend (red debug border) hitbox.
         - The AnchorPrefernceValue .center is in the center of the non-extended hitbox.
         */

        // north of center = scenario A
        if startY < 0 {
            //                                log("PortEntry: onChanged: north of center")
            diffFromCenter = diffFromCenter.update(height: -(totalDistanceY + 2))
        }
        // south of center = scenario C
        else if startY > 7 {
            //                                log("PortEntry: onChanged: south of center")
            diffFromCenter = diffFromCenter.update(height: totalDistanceY/2)
        }

        // west of center = scenario B
        if startX < 0 {
            //                                log("PortEntry: onChanged: west of center")
            diffFromCenter = diffFromCenter.update(width: -totalDistanceX)
        }
        // ... Apparently don't need to adjust if east of center?
        //

        return diffFromCenter
    }
}

extension GraphState {
    @MainActor
    func outputDragged(gesture: DragGesture.Value,
                       rowId: NodeRowViewModelId) {
                
        guard let outputRowViewModel = self.getOutputRowViewModel(for: rowId),
              let document = self.documentDelegate else {
            fatalErrorIfDebug()
            return
        }

        // TODO: WHY IS IT NECESSARY TO SUBTRACT OUT THE GRAPH ORIGIN? WHICH COORDINATE SPACE CAN AVOID THIS?
        var cursorLocationInGlobalCoordinateSpace = gesture.location
        let graphOrigin = self.graphPosition
        cursorLocationInGlobalCoordinateSpace.x -= graphOrigin.x
        cursorLocationInGlobalCoordinateSpace.y -= graphOrigin.y
        
        // exit edge editing state
        self.edgeEditingState = nil

        self.edgeAnimationEnabled = true
        
        // If we already have an active output-drag
        if let existingDrawingGesture = self.edgeDrawingObserver.drawingGesture {
            var drag: OutputDragGesture
            drag = existingDrawingGesture
            drag.cursorLocationInGlobalCoordinateSpace = cursorLocationInGlobalCoordinateSpace
        }
        
        // Starting new output-drag
        else {
            var gesture = gesture
            gesture.location = cursorLocationInGlobalCoordinateSpace
            let diffFromCenter = OutputNodeRowViewModel.calculateDiffFromCenter(from: gesture)
            
            let drag = OutputDragGesture(outputId: rowId,
                                         cursorLocationInGlobalCoordinateSpace: cursorLocationInGlobalCoordinateSpace,
                                         startingDiffFromCenter: diffFromCenter)
            
            self.edgeDrawingObserver.drawingGesture = drag
            
            // Wipe selected edges, canvas items. etc.
            self.resetAlertAndSelectionState(document: document)
            
            if let outputRowObserver = self.getOutputRowObserver(outputRowViewModel.nodeIOCoordinate),
               let canvasItemId = outputRowViewModel.canvasItemDelegate?.id {

                outputRowViewModel.portUIViewModel.updatePortColor(
                    canvasItemId: canvasItemId,
                    hasEdge: outputRowObserver.hasEdge,
                    hasLoop: outputRowObserver.hasLoopedValues,
                    selectedEdges: selectedEdges,
                    selectedCanvasItems: self.selectedCanvasItems,
                    drawingObserver: self.edgeDrawingObserver)
            }
        }
    }
    
    @MainActor
    func outputDragEnded() {
        guard let document = self.documentDelegate else {
            fatalErrorIfDebug()
            return
        }
        
        let graph = document.visibleGraph
        
        // We could have had an eligible canvas input and/or inspector input/input-field.
        // If we had both, prefer that inspector ?
        
        // We ought to have these if we were dragging an output
        guard let dragGesture = self.edgeDrawingObserver.drawingGesture,
              let dragOriginOutput = graph.getOutputRowViewModel(for: dragGesture.outputId),
              let draggedOutputObserver: OutputNodeRowObserver = self.getOutputRowObserver(dragOriginOutput.nodeIOCoordinate) else {
            
            fatalErrorIfDebug("Output drag ended but we did not have an edge drawing observer and/or could not retrieve the output row observer")
            
            self.edgeDrawingObserver.reset()
            
            DispatchQueue.main.async { [weak self] in
                self?.edgeAnimationEnabled = false
            }
            
            return
        }

        if let nearestEligible = self.edgeDrawingObserver.nearestEligibleEdgeDestination {
            self.createEdgeAfterPortDragEnded(
                nearestEligibleDestination: nearestEligible,
                sourceNodeId: draggedOutputObserver.id.nodeId,
                dragOriginOutput: dragOriginOutput,
                document: document)
            self.encodeProjectInBackground()
        }
        
        self.edgeDrawingObserver.reset()
    }
    
    @MainActor
    func createEdgeAfterPortDragEnded(nearestEligibleDestination: EligibleEdgeDestination,
                                      sourceNodeId: NodeId,
                                      dragOriginOutput: OutputNodeRowViewModel,
                                      document: StitchDocumentViewModel) {
        
        let dragOriginOutputUI = dragOriginOutput.portUIViewModel
        
        switch nearestEligibleDestination {
            
        case .canvasInput(let inputNodeRowViewModel):
            self.createEdgeFromEligibleCanvasInput(
                from: dragOriginOutputUI.portAddress,
                to: inputNodeRowViewModel.portUIViewModel.portAddress,
                // TODO: is the below still necessary?
                // Get node id from row observer, not row view model, in case edge drag is for group,
                // we want the splitter node delegate not the group node delegate
                sourceNodeId: sourceNodeId)
            
        case .inspectorInputOrField(let layerInputType):
            
            switch layerInputType.portType {
                
            case .packed:
                document.handleLayerInputAdded(
                    layerInput: layerInputType.layerInput,
                    draggedOutput: dragOriginOutputUI)
                
            case .unpacked(let unpackedPortType):
                document.handleLayerInputFieldAddedToCanvas(
                    layerInput: layerInputType.layerInput,
                    fieldIndex: unpackedPortType.rawValue,
                    draggedOutput: dragOriginOutputUI)
            }
        } // switch
    }
    
    @MainActor
    func createEdgeFromEligibleCanvasInput(from: OutputPortIdAddress?,
                                           to: InputPortIdAddress?,
                                           sourceNodeId: NodeId) {
        // Create visual edge if connecting two nodes
        if let from = from,
           let to = to {
            let newEdge = PortEdgeUI(from: from, to: to)
            
            // Why is this async ?
            DispatchQueue.main.async { [weak self] in
                self?.edgeDrawingObserver.reset()
            }

            self.edgeAdded(edge: newEdge)
        }

        // Then recalculate the graph again, with new edge,
        // starting at the 'from' node downward:
        self.scheduleForNextGraphStep(sourceNodeId)
    }
}

struct TimeHelpers {
    static let ThreeTenthsOfASecondInSeconds: Double = 0.3
    static let ThreeTenthsOfASecondInNanoseconds: Double = 300000000
}
