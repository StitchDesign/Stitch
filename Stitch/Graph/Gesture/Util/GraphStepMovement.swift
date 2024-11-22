//
//  GraphStepActions.swift
//  prototype
//
//  Created by Christian J Clampitt on 10/8/21.
//

import Foundation
import StitchSchemaKit
import CoreMedia

extension StitchDocumentViewModel {
    @MainActor
    func handleGraphMovementOnGraphStep() {
        let graphMovement = self.graphMovement
        
        guard self.graphMovement.shouldRun else {
            log("handleGraphMovementOnGraphStep: should not run momentum")
            return
        }

        // contains the updated
        let result = runMomentum(
            graphMovement.momentumState,
            shouldRunX: graphMovement.shouldRunX,
            shouldRunY: graphMovement.shouldRunY,
            x: graphMovement.localPosition.x,
            y: graphMovement.localPosition.y)

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
        graphMovement.momentumState = result.momentumState

        /*
         Potentially reset the momentum state

         Reset momentum along a momentum just if:
         1. momentum naturally ran its course, or
         2. momentum would carry us past a screen edge
         */
        var shouldResetMomentumX = graphMovement.momentumState.didXMomentumFinish

        var shouldResetMomentumY = graphMovement.momentumState.didYMomentumFinish

        /*
         Update the graphOffset with the new x and y positions,
         but cap them if we hit a border.

         Only look at bounds if we have nodes;
         otherwise just immediately update graph position.
         */

        let graphBounds = self.visibleGraph.graphBounds(
            graphMovement.zoomData.zoom,
            graphView: self.graphUI.frame,
            graphOffset: visibleGraph.localPosition,
            groupNodeFocused: self.graphUI.groupNodeFocused)

        let graphBoundsAtStart: GraphOriginAtStart? = self.graphMovement.graphBoundOriginAtStart

        // How does this situation arise?
        // If graphBoundsAtStart is not defined, then
        if !graphBoundsAtStart.isDefined {
            log("handleGraphMovementOnGraphStep: did not have graphBoundsAtStart")
        }

        if let graphBounds = graphBounds,
           let graphBoundsAtStart = graphBoundsAtStart {

            if graphMovement.momentumState.shouldRunX {

                // We're not passing in the post-momentum new offset;
                // rather, this looks at whether we're already at the border;
                // if we are, then we return this as a final position
                if let finalXOffset = graphMovement.capMomentumPositionX(
                    graphBounds: graphBounds,
                    frame: graphUI.frame,
                    zoom: graphMovement.zoomData.zoom,
                    startOrigins: graphBoundsAtStart.origin) {

                    // log("handleGraphMovementOnGraphStep: finalXOffset: \(finalXOffset)")
                    graphMovement.localPosition.x = finalXOffset
                    shouldResetMomentumX = true

                } else {
                    // log("handleGraphMovementOnGraphStep: no final x offset yet... ")
                    graphMovement.localPosition.x = postMomentumGraphOffsetX
                }
            } else {
                // log("shouldRunX was false; so will set shouldResetMomentumX true")
                shouldResetMomentumX = true
            }

            if graphMovement.momentumState.shouldRunY {

                if let finalYOffset = graphMovement.capMomentumPositionY(
                    graphBounds: graphBounds,
                    frame: graphUI.frame,
                    zoom: graphMovement.zoomData.zoom,
                    startOrigins: graphBoundsAtStart.origin) {

                    //                log("handleGraphMovementOnGraphStep: finalYOffset: \(finalYOffset)")
                    graphMovement.localPosition.y = finalYOffset
                    shouldResetMomentumY = true
                } else {
                    //                log("handleGraphMovementOnGraphStep: no final y offset yet... ")
                    graphMovement.localPosition.y = postMomentumGraphOffsetY
                }
            } else {
                //            log("shouldRunY was false; so will set shouldResetMomentumY true")
                shouldResetMomentumY = true
            }
        }

        // did not have graphBounds or graphBoundsAtStart
        else {
            //            log("handleGraphMovementOnGraphStep: did not have graphBounds; will use regular momentum")
            graphMovement.localPosition.x = postMomentumGraphOffsetX
            graphMovement.localPosition.y = postMomentumGraphOffsetY
        }

        //        log("handleGraphMovementOnGraphStep: did not have graphBounds; will use regular momentum")
        graphMovement.localPosition.x = postMomentumGraphOffsetX
        //        graphMovement.localPosition.y = postMomentumGraphOffsetY

        // Check each dimension for whether we finished:
        if shouldResetMomentumX {
            // log("handleGraphMovementOnGraphStep: resetting x momentum")
            graphMovement.momentumState.shouldRunX = false
            graphMovement.localPreviousPosition.x = graphMovement.localPosition.x

        }

        if shouldResetMomentumY {
            // log("handleGraphMovementOnGraphStep: resetting y momentum")
            graphMovement.momentumState.shouldRunY = false
            graphMovement.localPreviousPosition.y = graphMovement.localPosition.y
        }

        // If we're currently dragging node(s), treat graph momentum's change
        // of the graph's position as a change of a node's current and starting position (i.e. node.position and node.previousPosition)
        if graphMovement.canvasItemIsDragged {
            self.visibleGraph.selectedNodeIds.forEach { id in
                if let node = visibleGraph.getCanvasItem(id) {
                    node.previousPosition -= adjustment
                    node.position -= adjustment
                }
            }
        }

        if !graphMovement.shouldRun {
            graphMovement.resetGraphMovement()
            graphMovement.graphBoundOriginAtStart = nil

            // Wipe comment box bounds
            self.wipeCommentBoxBounds()
        }
    }
}
