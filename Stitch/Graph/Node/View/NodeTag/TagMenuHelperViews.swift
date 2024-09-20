//
//  TagMenuHelperViews.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/9/23.
//

import SwiftUI
import StitchSchemaKit

// TODO: button role and styling are probably less relevant now that we always use SwiftUI Menu for node / comment tag menus;
// SwiftUI Menu IGNORES styling etc.

// Button view commonly used in both node tag menu and comment tag menu
struct TagMenuButtonView: View {

    var label: String
    var role: ButtonRole?
    var action: () -> Void

    var body: some View {
        // BUG?: Does not use red color on Catalyst when we pass in .destructive ButtonRole
        StitchButton(role: role) { action() } label: {
            StitchTextView(string: label,
                           font: STITCH_NODE_TAG_FONT)
        }
    }
}

struct DeleteNodesButton: View {

    var label: String // = "Delete Nodes"
    var canvasItemId: CanvasItemId? // when called from comment box tag menu,

    var body: some View {
        TagMenuButtonView(label: label,
                          role: .destructive) {
            dispatch(SelectedGraphNodesDeleted(canvasItemId: canvasItemId))
        }
    }
}

struct DeleteCommentsOnlyButton: View {
    @Bindable var graph: GraphState

    var body: some View {
        TagMenuButtonView(label: "Delete Comments",
                          role: .destructive) {
            graph.deleteSelectedCommentBoxes()
        }
    }
}

struct DuplicateNodesButton: View {
    @Bindable var graph: GraphState

    var label: String // = "Duplicate"
    var nodeId: NodeId?

    var body: some View {
        TagMenuButtonView(label: label) {
            dispatch(DuplicateShortcutKeyPressed())
        }
    }
}

struct DuplicateCommentsOnlyButton: View {
    @Bindable var graph: GraphState

    var body: some View {
        TagMenuButtonView(label: "Duplicate Comments") {
            graph.selectedCommentBoxesDuplicated()
        }
    }
}
