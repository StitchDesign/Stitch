//
//  CommentBoxTitleEditView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/10/23.
//

import SwiftUI
import StitchSchemaKit

let superLongString = "Some SwiftUI views have a default background color that overrides whatever you try to apply yourself, but if you use the scrollContentBackground() modifier you can hide that default background and replace it with something else. At the time of writing, this works for List, TextEditor, and Form, so you can remove or change their background colors."

extension GraphUIState {
    func commentBoxTitleEditStarted(id: CommentBoxId) {
        self.activelyEditedCommentBoxTitle = id
    }

    func commentBoxTitleEditEnded() {
        self.activelyEditedCommentBoxTitle = nil
    }
}

struct CommentBoxTitleEdited: GraphEventWithResponse {
    let id: CommentBoxId
    let title: String

    func handle(state: GraphState) -> GraphResponse {
        guard let box = state.commentBoxesDict.get(id) else {
            log("CommentBoxTitleEdited: no box")
            return .noChange
        }

        box.title = title
        return .persistenceResponse
    }
}

struct CommentBoxTitleEditView: View {

    let id: CommentBoxId

    // the redux controlled value
    let isBeingEdited: Bool

    @State var isEditing = false
    @Binding var edit: String // = superLongString // "Default Text"
    @FocusState var focused: Bool

    var width: CGFloat // = 200
    var height: CGFloat // = 200

    func focusEditor() {
        focused = true
        isEditing = true
    }

    func defocusEditor() {
        focused = false
        isEditing = false
    }

    var body: some View {

        ZStack {

            // TODO: when graph tapped,
            //            Color.gray.opacity(0.5).onTapGesture {
            //                log("tapped")
            //                defocusEditor()
            //            }

            //            Rectangle().fill(.yellow.opacity(0.2))
            //                .frame(width: width, height: height)

            if isEditing {
                editor
                    .frame(width: width, height: height)
            } else {
                display
                    .padding(8)
                    .padding(.leading, -3) // -2 and -4 not good
                    .frame(width: width,
                           height: height,
                           alignment: .topLeading)
            }
        }
        .onAppear {
            self.isEditing = isBeingEdited
        }
        .onChange(of: isBeingEdited) { _, newValue in
            if newValue {
                focusEditor()
            } else {
                defocusEditor()
            }
        }

    }

    // problem is actually with Text, which does not
    var display: some View {
        Text(self.edit)
            .onTapGesture(count: 2) {
                focusEditor()
            }
    }

    var editor: some View {
        TextEditor(text: self.$edit)
            .scrollIndicators(.hidden)
            .scrollContentBackground(.hidden)
            .frame(minWidth: width, minHeight: height)
            .fixedSize(horizontal: true, vertical: false)
            //            .focused($focused)
            .focusedValue(\.focusedField, .commentBox(id))
            .onAppear {
                focused = true
            }
            .onChange(of: edit) { _, string in
                if string.last == "\n" {
                    print("Found new line character")
                    defocusEditor()
                    edit = string.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

    }
}

#Preview {
    CommentBoxTitleEditView(
        id: .fakeId,
        isBeingEdited: false,
        edit: .constant("love"),
        width: 200,
        height: 200)
}
