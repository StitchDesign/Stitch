//
//  CommentBoxMenuView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/8/23.
//

import SwiftUI
import StitchSchemaKit

struct CommentBoxTagMenuButtonsView: View {
    @Bindable var graph: GraphState
    @Bindable var box: CommentBoxViewModel
    let atleastOneNodeSelected: Bool

    var body: some View {
        deleteButton
        duplicateButton
        Button("Edit Title") {
            graph.graphUI.commentBoxTitleEditStarted(id: box.id)
        }
        commentBoxColorPicker
    }

    @MainActor
    var commentBoxColorPicker: some View {
        Menu {
            ForEach(CommentBoxViewModel.colorOptions, id: \.self) { color in
                Button(color.description.capitalized) {
                    box.color = color
                    graph.encodeProjectInBackground()
                }
            }
        } label: {
            Text("Change Color")
        }
    }

    @MainActor
    var deleteButton: some View {
        Group {
            if atleastOneNodeSelected {
                DeleteCommentsOnlyButton(graph: graph)
                DeleteNodesButton(label: "Delete Nodes")
            } else {
                Button("Delete") {
                    // Delete only this specific comment box;
                    graph.deleteCommentBox(box.id)
                }
            }
        }
    }

    @MainActor
    var duplicateButton: some View {
        Group {
            if atleastOneNodeSelected {
                DuplicateCommentsOnlyButton(graph: graph)
                DuplicateNodesButton(graph: graph,
                                     label: "Duplicate Nodes")
            } else {
                Button("Duplicate") {
                    graph.duplicateCommentBox(box: box)
                }
            }
        }
    }
}

//#Preview {
//    CommentBoxTagMenuButtonsView(graph: graph,
//                                 box: .init(zIndex: .zero,
//                                            scale: 1,
//                                            nodes: .init()),
//                                 atleastOneNodeSelected: false)
//}
