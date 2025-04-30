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
        
        let dragLocation = gesture.location
        self.edgeAnimationEnabled = true
        
        guard var existingDrawingGesture = self.edgeDrawingObserver.drawingGesture else {
            log("InputDragged: started")
            
            guard let upstreamObserver = inputRowObserver.upstreamOutputObserver?.rowViewModelForCanvasItemAtThisTraversalLevel else {
                return
            }
            
            self.edgeDrawingObserver.nearestEligibleInput = inputRowViewModel

            self.edgeDrawingObserver.drawingGesture = OutputDragGesture(output: upstreamObserver,
                                                                        dragLocation: dragLocation,
                                                                        startingDiffFromCenter: .zero)

            inputRowObserver.removeUpstreamConnection(node: node)
            node.scheduleForNextGraphStep()
            self.encodeProjectInBackground()
            
            return
        }

        // Called when drag has already started
        existingDrawingGesture.dragLocation = dragLocation
        self.edgeDrawingObserver.drawingGesture = existingDrawingGesture
    }
    
    @MainActor
    func inputDragEnded() {
        guard let drawingGesture = self.edgeDrawingObserver.drawingGesture,
              let fromRowObserver = self.getOutputRowObserver(drawingGesture.output.nodeIOCoordinate),
              let nearestEligibleInput = self.edgeDrawingObserver.nearestEligibleInput else {
            log("InputDragEnded: drag ended, but could not create new edge")
            self.edgeDrawingObserver.reset()
            
            DispatchQueue.main.async { [weak self] in
                self?.edgeAnimationEnabled = false
            }
            
            return
        }

        let to = nearestEligibleInput.portUIViewModel.portAddress
        let from = drawingGesture.output.portUIViewModel.portAddress
        
        self.edgeDrawingObserver.reset()

        let sourceNodeId = fromRowObserver.id.nodeId
        
        self.createEdgeFromEligibleInput(
            from: from,
            to: to,
            sourceNodeId: sourceNodeId)
                
        self.encodeProjectInBackground()
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

        // exit edge editing state
        self.edgeEditingState = nil

        self.edgeAnimationEnabled = true
        
        // Starting port drag
        if !self.edgeDrawingObserver.drawingGesture.isDefined {
            
            let diffFromCenter = OutputNodeRowViewModel.calculateDiffFromCenter(from: gesture)
            
            let drag = OutputDragGesture(output: outputRowViewModel,
                                         dragLocation: gesture.location,
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
            
        } else {
            guard let existingDrag = self.edgeDrawingObserver.drawingGesture else {
                // log("OutputDragged: output drag not yet initialized by SwiftUI handler; exiting early")
                return
            }

            var drag: OutputDragGesture
            drag = existingDrag
            drag.dragLocation = gesture.location

            self.edgeDrawingObserver.drawingGesture = drag
        }
    }
    
    @MainActor
    func outputDragEnded() {
        
        guard let from = self.edgeDrawingObserver.drawingGesture?.output,
              let to = self.edgeDrawingObserver.nearestEligibleInput,
              let fromRowObserver = self.getOutputRowObserver(from.nodeIOCoordinate) else {
            log("OutputDragEnded: No active output drag or eligible input ...")
            self.edgeDrawingObserver.reset()
            
            DispatchQueue.main.async { [weak self] in
                self?.edgeAnimationEnabled = false
            }
            
            return
        }
        
        self.edgeDrawingObserver.reset()
        
        // TODO: is the below still necessary?
        // Get node id from row observer, not row view model, in case edge drag is for group,
        // we want the splitter node delegate not the group node delegate
        let sourceNodeId = fromRowObserver.id.nodeId
        
        self.createEdgeFromEligibleInput(
            from: from.portUIViewModel.portAddress,
            to: to.portUIViewModel.portAddress,
            sourceNodeId: sourceNodeId)
        
        self.encodeProjectInBackground()
    }
}


extension GraphState {
    @MainActor
    func createEdgeFromEligibleInput(from: OutputPortIdAddress?,
                                     to: InputPortIdAddress?,
                                     sourceNodeId: NodeId) {
        // Create visual edge if connecting two nodes
        if let from = from,
           let to = to {
            let newEdge = PortEdgeUI(from: from, to: to)
            self.edgeDrawingObserver.recentlyDrawnEdge = newEdge
            
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

struct ResetRecentlyDrawnEdge: GraphEvent {
    func handle(state: GraphState) {
        state.edgeDrawingObserver.reset()
    }
}

struct TimeHelpers {
    static let ThreeTenthsOfASecondInSeconds: Double = 0.3
    static let ThreeTenthsOfASecondInNanoseconds: Double = 300000000
}
