//
//  CommentBoxActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/8/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension GraphState {
    /*
     HACK:

     Preferably we use currently selected nodes,
     but right-click can open .contextMenu without us selecting a node,
     in which case we use the passed in `nodeId`
     */
    @MainActor
    func commentBoxCreated(nodeId: CanvasItemId) {
        var selectedNodes = self.selectedNodeIds

        // Alternatively?: always add this id to selectedNodes in GraphUIState, so that we start it selected.
        if selectedNodes.isEmpty {
            selectedNodes = .init([nodeId])
        }

        let visibleNodes = self.visibleNodesViewModel
            .getVisibleCanvasItems(at: self.graphUI.groupNodeFocused?.asNodeId)

        let visibleSelectedNodes = visibleNodes
            .filter { selectedNodes.contains($0.id) }

        let box = CommentBoxViewModel(
            zIndex: self.highestZIndex + 1,
            scale: self.graphMovement.zoomData.zoom,
            nodes: visibleSelectedNodes)

        self.commentBoxesDict.updateValue(box, forKey: box.id)

        // Bad?: be smarter about how you create this?
        self.graphUI.commentBoxBoundsDict = .init()

        // Add the newly created comment box to "selected comment boxes"
        self.graphUI.selection.selectedCommentBoxes.insert(box.id)

        self.encodeProjectInBackground()
    }

    // Does NOT change selection state
    @MainActor
    func _duplicateSelectedComments(selectedComments: CommentBoxIdSet) -> [CommentBoxViewModel] {
        selectedComments.compactMap { id in
            guard let originalBox = self.commentBoxesDict.get(id) else {
                return nil
            }

            return self._duplicateCommentBox(originalBox: originalBox)
        }
    }

    // Only duplicates the comment box;
    // does not change comment-selection state etc.
    @MainActor
    func _duplicateCommentBox(originalBox: CommentBoxViewModel) -> CommentBoxViewModel {
        let schema = originalBox.createSchema()
        let duplicatedBox = CommentBoxViewModel()
        duplicatedBox.update(from: schema)

        // new id
        duplicatedBox.id = .init()

        // increment the position, startingPoint, anchorPoint etc.
        duplicatedBox.position = originalBox.position + .init(
            x: GRAPH_ITEM_POSITION_SHIFT_INCREMENT, // originalBox.expansionBox.size.width/2,
            y: GRAPH_ITEM_POSITION_SHIFT_INCREMENT) // originalBox.expansionBox.size.height/2)
        duplicatedBox.previousPosition = duplicatedBox.position

        // update expansion box's properties:
        duplicatedBox.expansionBox.anchorCorner = duplicatedBox.position
        duplicatedBox.expansionBox.startPoint = duplicatedBox.position

        duplicatedBox.nodes = .init()
        self.commentBoxesDict.updateValue(duplicatedBox, forKey: duplicatedBox.id)

        return duplicatedBox
    }

    // Modifies selection state for comment box
    @MainActor
    func duplicateCommentBox(box: CommentBoxViewModel) {
        let newCommentBox = _duplicateCommentBox(
            originalBox: box)

        // deselect the original box and select the duplicated box
        self.graphUI.selection.selectedCommentBoxes.remove(box.id)
        self.graphUI.selection.selectedCommentBoxes.insert(newCommentBox.id)

        self.encodeProjectInBackground()
    }

    @MainActor
    func deleteSelectedCommentBoxes() {
        let selectedBoxes = self.graphUI.selection.selectedCommentBoxes
        for selectedBoxId in selectedBoxes {
            // delete a comment box = remove its definition from GraphSchema and its bounds from GraphUIState, but leave nodes alone
            self.deleteCommentBox(selectedBoxId)
        }
    }

    @MainActor
    func deleteCommentBox(_ id: CommentBoxId) {
        self.commentBoxesDict.removeValue(forKey: id)
        self.graphUI.commentBoxBoundsDict.removeValue(forKey: id)
        self.graphUI.selection.selectedCommentBoxes.remove(id)
        self.encodeProjectInBackground()
    }
}

// Used when we have a GraphState
// func duplicateSelectedCommentBoxes(graphSchema: GraphSchema,
//                                   graphState: GraphState,
//                                   // If duplicating ONLY comment boxes,
//                                   // then deselect nodes as well.
//                                   duplicatingCommentsOnly: Bool) -> GraphSchema {
//
//    var graphSchema = graphSchema
//
//    for id in graphState.graphUI.selection.selectedCommentBoxes {
//        graphSchema = duplicateCommentBox(
//            id,
//            graphSchema: graphSchema,
//            graphState: graphState)
//    }
//
//    if duplicatingCommentsOnly {
//        graphState.graphUI.selection = graphState.graphUI.selection.resetSelectedNodes()
//    }
//
//    return graphSchema
// }
