//
//  PortDragActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/19/22.
//

import SwiftUI
import StitchSchemaKit

extension InputNodeRowViewModel {
    @MainActor
    func portDragged(gesture: DragGesture.Value,
                     graphState: GraphState) {
        
        let dragLocation = gesture.location
        graphState.edgeAnimationEnabled = true

        guard let node = graphState.getNode(self.id.nodeId) else {
            fatalErrorIfDebug()
            return
        }
        
        guard var existingDrawingGesture = graphState.edgeDrawingObserver.drawingGesture else {
            log("InputDragged: started")
            
            guard let upstreamObserver = self.rowDelegate?.upstreamOutputObserver?.nodeRowViewModel else {
//                fatalErrorIfDebug()
                return
            }
            
            graphState.edgeDrawingObserver.nearestEligibleInput = self

            graphState.edgeDrawingObserver.drawingGesture = OutputDragGesture(output: upstreamObserver,
                                                                              dragLocation: dragLocation,
                                                                              startingDiffFromCenter: .zero)

            self.rowDelegate?.removeUpstreamConnection(node: node)
            self.nodeDelegate?.scheduleForNextGraphStep()
            graphState.encodeProjectInBackground()
            
            return
        }

        // Called when drag has already started
        existingDrawingGesture.dragLocation = dragLocation
        graphState.edgeDrawingObserver.drawingGesture = existingDrawingGesture
    }
    
    @MainActor
    func portDragEnded(graphState: GraphState) {
        guard let drawingGesture = graphState.edgeDrawingObserver.drawingGesture,
              let fromRowObserver = graphState.getOutputRowObserver(drawingGesture.output.nodeIOCoordinate),
              let nearestEligibleInput = graphState.edgeDrawingObserver.nearestEligibleInput else {
            log("InputDragEnded: drag ended, but could not create new edge")
            graphState.edgeDrawingObserver.reset()
            
            DispatchQueue.main.async { [weak graphState] in
                graphState?.edgeAnimationEnabled = false
            }
            
            return
        }

        let to = nearestEligibleInput.portViewData
        let from = drawingGesture.output.portViewData
        
        graphState.edgeDrawingObserver.reset()

        let sourceNodeId = fromRowObserver.id.nodeId
        
        graphState.createEdgeFromEligibleInput(
            from: from,
            to: to,
            sourceNodeId: sourceNodeId)
                
        graphState.encodeProjectInBackground()
    }
    
    // While dragging cursor from an output/input,
    // we've detected that we're over an eligible input
    // to which we could create a connection.
    @MainActor
    func eligibleInputDetected(graphState: GraphState) {
        graphState.edgeDrawingObserver.nearestEligibleInput = self
    }
}

extension OutputNodeRowViewModel {
    @MainActor
    func portDragged(gesture: DragGesture.Value,
                     graphState: GraphState) {
        
        guard let document = graphState.documentDelegate else {
            fatalErrorIfDebug()
            return
        }

        // exit edge editing state
        graphState.edgeEditingState = nil

        graphState.edgeAnimationEnabled = true
        
        //        log("OutputDragStarted: output: \(output)")
        //        log("OutputDragStarted: diffFromCenter: \(diffFromCenter)")
        //        log("OutputDragStarted: state.outputDragStartedCount: \(state.outputDragStartedCount)")

        // TODO: decide whether to allow simultaneous node-movement and edge-drawing?
        //        guard !state.nodeIsMoving else {
        //            log("OutputDragStarted: exiting early: node is moving")
        //            return .noChange
        //        }

        // Starting port drag
        if !graphState.edgeDrawingObserver.drawingGesture.isDefined {
            
            graphState.outputDragStartedCount += 1

            let diffFromCenter = Self.calculateDiffFromCenter(from: gesture)

            // 3 still allows flashing;
            // 10 creates a noticeable lag;
            // 5 is perfect?
            guard graphState.outputDragStartedCount > 5 else {
                // log("OutputDragged: exiting early: state.outputDragStartedCount was: \(state.outputDragStartedCount)")
                return
            }

            let drag = OutputDragGesture(output: self,
                                         dragLocation: gesture.location,
                                         startingDiffFromCenter: diffFromCenter)

            graphState.edgeDrawingObserver.drawingGesture = drag

            // Wipe selected edges, canvas items. etc.
            graphState.resetAlertAndSelectionState(document: document)
            
            //        log("OutputDragStarted: state.edgeDrawingObserver.drawingGesture: \(state.edgeDrawingObserver.drawingGesture)")
        } else {
            graphState.outputDragStartedCount = 0

            guard let existingDrag = graphState.edgeDrawingObserver.drawingGesture else {
                // log("OutputDragged: output drag not yet initialized by SwiftUI handler; exiting early")
                return
            }

            var drag: OutputDragGesture
            drag = existingDrag
            drag.dragLocation = gesture.location

            graphState.edgeDrawingObserver.drawingGesture = drag
        }
    }

    static func calculateDiffFromCenter(from gesture: DragGesture.Value) -> CGSize {
        let startX = gesture.startLocation.x
        let startY = gesture.startLocation.y

        let xDistanceFromLocalCenter = startX.magnitude
        let yDistanceFromLocalCenter = startY.magnitude

        let localCenterDistanceFromAnchorCenterX = PORT_ENTRY_NON_EXTENDED_HITBOX_SIZE.width/2
        let localCenterDistanceFromAnchorCenterY = PORT_ENTRY_NON_EXTENDED_HITBOX_SIZE.height/2

        let totalDistanceX = xDistanceFromLocalCenter + localCenterDistanceFromAnchorCenterX
        let totalDistanceY = yDistanceFromLocalCenter + localCenterDistanceFromAnchorCenterY

        //                            log("PortEntry: onChanged: .local: startX: \(startX)")
        //                            log("PortEntry: onChanged: .local: xDistanceFromLocalCenter: \(xDistanceFromLocalCenter)")
        //                            log("PortEntry: onChanged: .local: localCenterDistanceFromAnchorCenterX: \(localCenterDistanceFromAnchorCenterX)")
        //                            log("PortEntry: onChanged: .local: totalDistanceX: \(totalDistanceX)")

        //                            log("PortEntry: onChanged: .local: startY: \(startY)")
        //                            log("PortEntry: onChanged: .local: yDistanceFromLocalCenter: \(yDistanceFromLocalCenter)")
        //                            log("PortEntry: onChanged: .local: localCenterDistanceFromAnchorCenterY: \(localCenterDistanceFromAnchorCenterY)")
        //                            log("PortEntry: onChanged: .local: totalDistanceY: \(totalDistanceY)")

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
    
    @MainActor func portDragEnded(graphState: GraphState) {
        //        let disableEdgeAnimationEffect: Effect = createDelayedEffect(
        //            delayInNanoseconds: TimeHelpers.ThreeTenthsOfASecondInNanoseconds,
        //            action: DisableEdgeAnimation())
        
        // reset the count
        graphState.outputDragStartedCount = 0
        
        guard let from = graphState.edgeDrawingObserver.drawingGesture?.output,
              let to = graphState.edgeDrawingObserver.nearestEligibleInput,
              let fromRowObserver = graphState.getOutputRowObserver(from.nodeIOCoordinate) else {
            log("OutputDragEnded: No active output drag or eligible input ...")
            graphState.edgeDrawingObserver.reset()
            
            DispatchQueue.main.async { [weak graphState] in
                graphState?.edgeAnimationEnabled = false
            }
            
            return
        }
        
        graphState.edgeDrawingObserver.reset()
        
        // TODO: is the below still necessary?
        // Get node id from row observer, not row view model, in case edge drag is for group,
        // we want the splitter node delegate not the group node delegate
        let sourceNodeId = fromRowObserver.id.nodeId
        
        graphState.createEdgeFromEligibleInput(
            from: from.portViewData,
            to: to.portViewData,
            sourceNodeId: sourceNodeId)
        
        graphState.encodeProjectInBackground()
    }
}

struct EligibleInputReset: ProjectEnvironmentEvent {
    func handle(graphState: GraphState,
                environment: StitchEnvironment) -> GraphResponse {
        graphState.edgeDrawingObserver.nearestEligibleInput = nil
        return .noChange
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
//            let resetRecentlyDrawnEdgeEffect: Effect = createDelayedEffect(
//                delayInNanoseconds: TimeHelpers.ThreeTenthsOfASecondInNanoseconds,
//                action: ResetRecentlyDrawnEdge())
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

//struct DisableEdgeAnimation: GraphEvent {
//    func handle(state: GraphState) {
//        state.edgeAnimationEnabled = false
//    }
//}

struct TimeHelpers {
    static let ThreeTenthsOfASecondInSeconds: Double = 0.3
    static let ThreeTenthsOfASecondInNanoseconds: Double = 300000000
}
