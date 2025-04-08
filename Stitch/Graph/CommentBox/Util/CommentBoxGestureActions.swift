//
//  CommentBoxGestureActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/8/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension GraphState {
    @MainActor
    func commentBoxTapped(box: CommentBoxViewModel) {
        
        guard let document = self.documentDelegate else {
            fatalErrorIfDebug()
            return
        }
        
        // If CMD held:
        // TODO: pass this down from the gesture handler
        if document.keypressState.isCommandPressed {
            if self.selection
                .selectedCommentBoxes.contains(id) {
                self.selection.selectedCommentBoxes.remove(id)
            } else {
                self.selection.selectedCommentBoxes.insert(id)
            }
        }

        // CMD not held, so select this box and deselect everything else
        else {
            // reset selection state; select only this comment box
            self.selection = .init()
            self.selection.selectedCommentBoxes = Set([id])
        }

        box.zIndex = self.highestZIndex + 1

        self.encodeProjectInBackground()
    }

    @MainActor
    func commentBoxPositionDragged(id: CommentBoxId,
                                   value: DragGesture.Value) {

        // log("CommentBoxPositionDragged called")
        let zoom: CGFloat = self.graphMovement.zoomData

        // log("CommentBoxPositionDragged: value.translation: \(value.translation)")
        // log("CommentBoxPositionDragged: value.translation / zoom: \(value.translation / zoom)")

        self.selection.selectedCommentBoxes.insert(id)

        let selectedBoxes = self.selection.selectedCommentBoxes
        self.selection.selectedCommentBoxes = Set(selectedBoxes)

        // log("CommentBoxPositionDragged: selectedBoxes: \(selectedBoxes)")

        for boxId in selectedBoxes {

            if let box = self.commentBoxesDict.get(boxId) {

                // log("CommentBoxPositionDragged: box.previousPosition: \(box.previousPosition)")
                // log("CommentBoxPositionDragged: box.position was: \(box.position)")

                // TODO: get rid of box.position and only use box.expansionBox.anchorCorner and box.expansion.startPoint ?
                box.position.x = box.previousPosition.x + (value.translation.width / zoom)
                box.position.y = box.previousPosition.y + (value.translation.height / zoom)

                // log("CommentBoxPositionDragged: box.position is now: \(box.position)")

                // log("CommentBoxPositionDragged: box.expansionBox.anchorCorner was: \(box.expansionBox.anchorCorner)")

                // log("CommentBoxPositionDragged: box.expansionBox.startPoint was: \(box.expansionBox.startPoint)")

                box.expansionBox.anchorCorner = box.position
                box.expansionBox.startPoint = box.position

                // update box's z-index
                box.zIndex = self.highestZIndex + 1

                self.commentBoxesDict.updateValue(box, forKey: boxId)

                // update the positions of this comment box's nodes;
                // note that we don't update the nodes' z-indices here
                self.updatesNodesAfterCommentBoxDrag(
                    box,
                    translation: value.translation)

            } else {
                log("CommentBoxPositionDragged: could not retrieve comment box \(boxId)")
            }

        } // for boxId in ...
    }

    // update the positions of the nodes for this specific comment box
    @MainActor
    func updatesNodesAfterCommentBoxDrag(_ box: CommentBoxViewModel,
                                         translation: CGSize) {
        // log("CommentBoxPositionDragged: box.nodes: \(box.nodes)")

        // TODO: CommentBox should support Nodes and LayerInputsOnGraph
        // Update box's nodes:
        for nodeId in box.nodes {
            // During drag itself, we just update the node view model
            if let node = self.getCanvasItem(nodeId) {
                self.updateCanvasItemOnDragged(node,
                                               translation: translation)

                self.nodeIsMoving = true
            }
        }
    }

    @MainActor
    func commentBoxPositionDragEnded() {
        // log("CommentBoxPositionDragEnded called")

        for id in self.selection.selectedCommentBoxes {
            if let box = self.commentBoxesDict.get(id) {

                box.previousPosition = box.position

                // TODO: do we need to update box.expansionBox.anchorPoint as well?
                box.expansionBox.startPoint = box.position

                // added
                box.expansionBox.anchorCorner = box.position

                self.updateNodesAfterCommentBoxDragEnded(box)

                // Remove the bounds-dict entry so that view will repopulate/refresh the bounds-dict for that
                self.commentBoxBoundsDict.removeValue(forKey: id)

            } else {
                log("CommentBoxPositionDragEnded: could not retrieve comment box \(id)")
            }

        } // for boxId in ...

        self.encodeProjectInBackground()
    }

    @MainActor
    func updateNodesAfterCommentBoxDragEnded(_ box: CommentBoxViewModel) {
        // Update box's nodes:
        for nodeId in box.nodes {
            // When drag ends, we update both the node view model and the node schema
            if let node = self.getCanvasItem(nodeId) {
                // update node view model
                node.previousPosition = node.position

            } else {
                log("CommentBoxPositionDragEnded: could not retrieve node view model \(nodeId)")
            }
        }

        self.nodeIsMoving = false
    }

    @MainActor
    func commentBoxExpansionDragged(box: CommentBoxViewModel,
                                    value: DragGesture.Value) {
        self.selection.selectedCommentBoxes = Set([box.id])

        let zoom = self.graphMovement.zoomData

        // STEP 1: UPDATE THE COMMENT BOX ITSELF
        box.expansionBox.startPoint = box.position
        box.expansionBox.endPoint = value.location

        box.zIndex = self.highestZIndex + 1

        //        let scaledTranslation = CGSize(
        //            width: value.translation.width/zoom,
        //            height: value.translation.height/zoom)

        let (newSize, newDirection, newAnchorPoint) = commentBoxTrigCalc(
            start: box.expansionBox.startPoint,
            end: box.expansionBox.endPoint, // gesture location
            previousSize: box.expansionBox.previousSize,
            // Scaling translation not needed when using same coordinate space as nodes
            translation: value.translation,
            existingExpansionDirection: box.expansionBox.expansionDirection,
            existingAnchorPoint: box.expansionBox.anchorCorner,
            previousPosition: box.previousPosition)

        // print("expansionDrag: newSize: \(newSize)")
        // print("expansionDrag: newDirection: \(newDirection)")
        // print("expansionDrag: newAnchorPoint: \(newAnchorPoint)")

        box.expansionBox.size = newSize
        box.expansionBox.expansionDirection = newDirection

        // Note: we update anchorCorner but position
        box.expansionBox.anchorCorner = newAnchorPoint

        // Note: we only re-determine nodes for this comment box when expansion drag ENDS
    }

    @MainActor
    func commentBoxExpansionDragEnded(box: CommentBoxViewModel,
                                      value: DragGesture.Value,
                                      newestBoxBounds: CommentBoxBounds,
                                      groupNodeFocused: NodeId?) {
        // ALWAYS update this comment box's bounds
        self.commentBoxBoundsDict.updateValue(
            newestBoxBounds,
            forKey: id)

        // RE-DETERMINE WHICH NODES FALL WITHIN THIS COMMENT BOX
        // Assumes this comment box's bounds were recently updated
        self.rebuildCommentBoxes(currentTraversalLevel: groupNodeFocused)

        guard let box = self.commentBoxesDict.get(id) else {
            log("CommentBoxExpansionDragEnded: could not retrieve comment box \(id)")
            return
        }

        // wipe start-location when done, but don't wipe expansion box size, since we want the box to stay around
        box.expansionBox.endPoint = value.location // .zero
        box.expansionBox.previousSize = box.expansionBox.size
        box.expansionBox.expansionDirection = nil // reset
        box.position = box.expansionBox.anchorCorner
        box.previousPosition = box.position

        self.encodeProjectInBackground()
    }

    @MainActor
    func updateCommentBoxBounds(box: CommentBoxViewModel,
                                bounds: CommentBoxBounds,
                                groupNodeFocused: NodeId?) {

        // log("UpdateCommentBoxBounds: id: \(id)")
        // log("UpdateCommentBoxBounds: bounds: \(bounds)")

        // Add this box's bounds to the bounds-dict
        self.commentBoxBoundsDict.updateValue(
            bounds,
            forKey: id)

        // Then redetermine which nodes fall into the boxes
        // TODO: only redetermine for this single box, not all boxes?
        self.rebuildCommentBoxes(currentTraversalLevel: groupNodeFocused)

        self.encodeProjectInBackground()
    }
}
