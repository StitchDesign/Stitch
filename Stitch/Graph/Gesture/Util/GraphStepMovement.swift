//
//  GraphStepActions.swift
//  prototype
//
//  Created by Christian J Clampitt on 10/8/21.
//

import Foundation
import StitchSchemaKit
import CoreMedia

extension GraphState {
    @MainActor
    func handleGraphMovementOnGraphStep() {

        let graphState: GraphState = self

        guard graphState.graphMovement.shouldRun else {
            log("handleGraphMovementOnGraphStep: should not run momentum")
            return
        }

        // contains the updated
        let result = runMomentum(
            graphState.graphMovement.momentumState,
            shouldRunX: graphState.graphMovement.shouldRunX,
            shouldRunY: graphState.graphMovement.shouldRunY,
            x: graphState.graphMovement.localPosition.x,
            y: graphState.graphMovement.localPosition.y)

        // This is the FINAL POSITION,
        // if we apply momentum;
        // ie current offset + delta from momentum
        let postMomentumGraphOffsetX = result.x
        let postMomentumGraphOffsetY = result.y

        // log("handleGraphMovementOnGraphStep: postMomentumGraphOffsetX: \(postMomentumGraphOffsetX)")

        // For adjusting actively dragged nodes' positioning
        let adjustment = result.momentumState.delta

        // Set the updated momentum animation state in the GraphMovement state,
        // since we've modified the delta, amplitude etc.
        graphState.graphMovement.momentumState = result.momentumState

        /*
         Potentially reset the momentum state

         Reset momentum along a momentum just if:
         1. momentum naturally ran its course, or
         2. momentum would carry us past a screen edge
         */
        var shouldResetMomentumX = graphState.graphMovement.momentumState.didXMomentumFinish

        var shouldResetMomentumY = graphState.graphMovement.momentumState.didYMomentumFinish

        /*
         Update the graphOffset with the new x and y positions,
         but cap them if we hit a border.

         Only look at bounds if we have nodes;
         otherwise just immediately update graph position.
         */

        let graphBounds = graphState.graphBounds(
            graphState.graphMovement.zoomData.zoom,
            graphView: graphState.graphUI.frame,
            graphOffset: graphState.localPosition,
            groupNodeFocused: graphState.graphUI.groupNodeFocused)

        let graphBoundsAtStart: GraphOriginAtStart? = graphState.graphMovement.graphBoundOriginAtStart

        // How does this situation arise?
        // If graphBoundsAtStart is not defined, then
        if !graphBoundsAtStart.isDefined {
            log("handleGraphMovementOnGraphStep: did not have graphBoundsAtStart")
        }

        if let graphBounds = graphBounds,
           let graphBoundsAtStart = graphBoundsAtStart {

            if graphState.graphMovement.momentumState.shouldRunX {

                // We're not passing in the post-momentum new offset;
                // rather, this looks at whether we're already at the border;
                // if we are, then we return this as a final position
                if let finalXOffset = graphState.graphMovement.capMomentumPositionX(
                    graphBounds: graphBounds,
                    frame: graphUI.frame,
                    zoom: graphMovement.zoomData.zoom,
                    startOrigins: graphBoundsAtStart.origin) {

                    // log("handleGraphMovementOnGraphStep: finalXOffset: \(finalXOffset)")
                    graphState.graphMovement.localPosition.x = finalXOffset
                    shouldResetMomentumX = true

                } else {
                    // log("handleGraphMovementOnGraphStep: no final x offset yet... ")
                    graphState.graphMovement.localPosition.x = postMomentumGraphOffsetX
                }
            } else {
                // log("shouldRunX was false; so will set shouldResetMomentumX true")
                shouldResetMomentumX = true
            }

            if graphState.graphMovement.momentumState.shouldRunY {

                if let finalYOffset = graphState.graphMovement.capMomentumPositionY(
                    graphBounds: graphBounds,
                    frame: graphUI.frame,
                    zoom: graphMovement.zoomData.zoom,
                    startOrigins: graphBoundsAtStart.origin) {

                    //                log("handleGraphMovementOnGraphStep: finalYOffset: \(finalYOffset)")
                    graphState.graphMovement.localPosition.y = finalYOffset
                    shouldResetMomentumY = true
                } else {
                    //                log("handleGraphMovementOnGraphStep: no final y offset yet... ")
                    graphState.graphMovement.localPosition.y = postMomentumGraphOffsetY
                }
            } else {
                //            log("shouldRunY was false; so will set shouldResetMomentumY true")
                shouldResetMomentumY = true
            }
        }

        // did not have graphBounds or graphBoundsAtStart
        else {
            //            log("handleGraphMovementOnGraphStep: did not have graphBounds; will use regular momentum")
            graphState.graphMovement.localPosition.x = postMomentumGraphOffsetX
            graphState.graphMovement.localPosition.y = postMomentumGraphOffsetY
        }

        //        log("handleGraphMovementOnGraphStep: did not have graphBounds; will use regular momentum")
        graphState.graphMovement.localPosition.x = postMomentumGraphOffsetX
        //        graphState.graphMovement.localPosition.y = postMomentumGraphOffsetY

        // Check each dimension for whether we finished:
        if shouldResetMomentumX {
            // log("handleGraphMovementOnGraphStep: resetting x momentum")
            graphState.graphMovement.momentumState.shouldRunX = false
            graphState.graphMovement.localPreviousPosition.x = graphState.graphMovement.localPosition.x

        }

        if shouldResetMomentumY {
            // log("handleGraphMovementOnGraphStep: resetting y momentum")
            graphState.graphMovement.momentumState.shouldRunY = false
            graphState.graphMovement.localPreviousPosition.y = graphState.graphMovement.localPosition.y
        }

        // If we're currently dragging node(s), treat graph momentum's change
        // of the graph's position as a change of a node's current and starting position (i.e. node.position and node.previousPosition)
        if graphState.graphMovement.canvasItemIsDragged {
            graphState.selectedNodeIds.forEach { (id: NodeId) in
                if var node = graphState.visibleNodesViewModel
                    .getViewModel(id) {
                    node.previousPosition -= adjustment
                    node.position -= adjustment
                }
            }
        }

        if !graphState.graphMovement.shouldRun {
            graphState.graphMovement.resetGraphMovement()
            graphState.graphMovement.graphBoundOriginAtStart = nil

            // Wipe comment box bounds
            graphState.wipeCommentBoxBounds()
        }
    }
}
