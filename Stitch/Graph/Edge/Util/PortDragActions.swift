//
//  PortDragActions.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/19/22.
//

import SwiftUI
import StitchSchemaKit

struct InputDragged: ProjectEnvironmentEvent {
    let inputObserver: NodeRowObserver
    let dragLocation: CGPoint

    func handle(graphState: GraphState,
                computedGraphState: ComputedGraphState,
                environment: StitchEnvironment) -> GraphResponse {
        
        graphState.graphUI.edgeAnimationEnabled = true

        guard var existingDrawingGesture = graphState.edgeDrawingObserver.drawingGesture else {
            log("InputDragged: started")
            
            guard let upstreamObserver = inputObserver.upstreamOutputObserver else {
//                fatalErrorIfDebug()
                return .noChange
            }
            
            graphState.edgeDrawingObserver.nearestEligibleInput = inputObserver

            graphState.edgeDrawingObserver.drawingGesture = OutputDragGesture(output: upstreamObserver,
                                                                              dragLocation: dragLocation,
                                                                              startingDiffFromCenter: .zero)

            inputObserver.removeUpstreamConnection()

            graphState.calculate(inputObserver.id.nodeId)
            return .persistenceResponse
        }

        // Called when drag has already started
        existingDrawingGesture.dragLocation = dragLocation
        graphState.edgeDrawingObserver.drawingGesture = existingDrawingGesture

        return .noChange
    }
}

struct OutputDragged: GraphEvent {

    let outputRowObserver: NodeRowObserver
    let gesture: DragGesture.Value

    func handle(state: GraphState) {

        // exit edge editing state
        state.graphUI.edgeEditingState = nil

        state.graphUI.edgeAnimationEnabled = true

        //        log("OutputDragStarted: output: \(output)")
        //        log("OutputDragStarted: diffFromCenter: \(diffFromCenter)")
        //        log("OutputDragStarted: state.outputDragStartedCount: \(state.outputDragStartedCount)")

        // TODO: decide whether to allow simultaneous node-movement and edge-drawing?
        //        guard !state.nodeIsMoving else {
        //            log("OutputDragStarted: exiting early: node is moving")
        //            return .noChange
        //        }

        // Starting port drag
        if !state
            .edgeDrawingObserver
            .drawingGesture
            .isDefined {
            state.outputDragStartedCount += 1

            let diffFromCenter = Self.calculateDiffFromCenter(from: gesture)

            // 3 still allows flashing;
            // 10 creates a noticeable lag;
            // 5 is perfect?
            guard state.outputDragStartedCount > 5 else {
                // log("OutputDragged: exiting early: state.outputDragStartedCount was: \(state.outputDragStartedCount)")
                return
            }

            let drag = OutputDragGesture(output: outputRowObserver,
                                         dragLocation: gesture.location,
                                         startingDiffFromCenter: diffFromCenter)

            state.edgeDrawingObserver.drawingGesture = drag

            //        log("OutputDragStarted: state.edgeDrawingObserver.drawingGesture: \(state.edgeDrawingObserver.drawingGesture)")
        } else {
            state.outputDragStartedCount = 0

            guard let existingDrag = state.edgeDrawingObserver.drawingGesture else {
                // log("OutputDragged: output drag not yet initialized by SwiftUI handler; exiting early")
                return
            }

            var drag: OutputDragGesture
            drag = existingDrag
            drag.dragLocation = gesture.location

            state.edgeDrawingObserver.drawingGesture = drag
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
}

struct InputDragEnded: ProjectEnvironmentEvent {

    func handle(graphState: GraphState,
                computedGraphState: ComputedGraphState,
                environment: StitchEnvironment) -> GraphResponse {

        let disableEdgeAnimationEffect: Effect = createDelayedEffect(
            delayInNanoseconds: TimeHelpers.ThreeTenthsOfASecondInNanoseconds,
            action: DisableEdgeAnimation())

        
        guard let drawingGesture = graphState.edgeDrawingObserver.drawingGesture,
              let to = graphState.edgeDrawingObserver.nearestEligibleInput?.inputPortViewData,
              let from = drawingGesture.output.outputPortViewData else {
            log("InputDragEnded: drag ended, but could not create new edge")
            
            // TODO: why wasn't this necessary in the original Edge Perf PR?
            graphState.edgeDrawingObserver.drawingGesture?.output.updatePortColor()
            
            graphState.edgeDrawingObserver.reset()
            return .effectOnly(disableEdgeAnimationEffect)
        }

        graphState.edgeDrawingObserver.reset()

        graphState.createEdgeFromEligibleInput(
            from: from,
            to: to)
                
        return .init(effects: [disableEdgeAnimationEffect], willPersist: true)
    }
}

struct OutputDragEnded: ProjectEnvironmentEvent {

    func handle(graphState: GraphState,
                computedGraphState: ComputedGraphState,
                environment: StitchEnvironment) -> GraphResponse {
        //        log("OutputDragEnded called")

        let disableEdgeAnimationEffect: Effect = createDelayedEffect(
            delayInNanoseconds: TimeHelpers.ThreeTenthsOfASecondInNanoseconds,
            action: DisableEdgeAnimation())

        // reset the count
        graphState.outputDragStartedCount = 0

        guard let from = graphState.edgeDrawingObserver.drawingGesture?.output.outputPortViewData,
              let to = graphState.edgeDrawingObserver.nearestEligibleInput?.inputPortViewData else {
            log("OutputDragEnded: No active output drag or eligible input ...")
            graphState.edgeDrawingObserver.reset()
            //            return .noChange
            return .effectOnly(disableEdgeAnimationEffect)
        }

        graphState.edgeDrawingObserver.reset()

        graphState.createEdgeFromEligibleInput(
            from: from,
            to: to)

        return .init(effects: [disableEdgeAnimationEffect], willPersist: true)
    }
}

// While dragging cursor from an output/input,
// we've detected that we're over an eligible input
// to which we could create a connection.
struct EligibleInputDetected: ProjectEnvironmentEvent {
    // candidate input
    let input: NodeRowObserver

    func handle(graphState: GraphState,
                computedGraphState: ComputedGraphState,
                environment: StitchEnvironment) -> GraphResponse {
        graphState.edgeDrawingObserver.nearestEligibleInput = input
        return .noChange
    }
}

struct EligibleInputReset: ProjectEnvironmentEvent {
    func handle(graphState: GraphState,
                computedGraphState: ComputedGraphState,
                environment: StitchEnvironment) -> GraphResponse {
        graphState.edgeDrawingObserver.nearestEligibleInput = nil
        return .noChange
    }
}

extension GraphState {
    @MainActor
    func createEdgeFromEligibleInput(from: OutputPortViewData,
                                     to: InputPortViewData) {
        
        let newEdge = PortEdgeUI(from: from, to: to)
        self.edgeDrawingObserver.recentlyDrawnEdge = newEdge

        let resetRecentlyDrawnEdgeEffect: Effect = createDelayedEffect(
            delayInNanoseconds: TimeHelpers.ThreeTenthsOfASecondInNanoseconds,
            action: ResetRecentlyDrawnEdge())

        self.edgeAdded(edge: newEdge)

        [resetRecentlyDrawnEdgeEffect].processEffects()
    }
}

struct ResetRecentlyDrawnEdge: GraphEvent {
    func handle(state: GraphState) {
        state.edgeDrawingObserver.reset()
    }
}

struct DisableEdgeAnimation: GraphEvent {
    func handle(state: GraphState) {
        state.graphUI.edgeAnimationEnabled = false
    }
}

struct TimeHelpers {
    static let ThreeTenthsOfASecondInSeconds: Double = 0.3
    static let ThreeTenthsOfASecondInNanoseconds: Double = 300000000
}
