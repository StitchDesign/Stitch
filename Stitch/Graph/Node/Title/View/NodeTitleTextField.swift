//
//  NodeTextField.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 12/15/22.
//

import SwiftUI
import StitchSchemaKit

struct NodeTitleTextField: View {
    @Bindable var graph: GraphState
    let id: CanvasItemId
    let label: String
    var font: Font = STITCH_FONT

    var body: some View {
        StitchTitleTextField(graph: graph,
                             titleEditType: .canvas(id),
                             label: label,
                             font: font)
    }
}
    /// A wrapper view for `TextField` which renders a read-only view when the input isn't in focus. This fixes a performance
    /// issue with `TextField` which becomes exacerbated by many rendered `TextField`'s in a view.
struct StitchTitleTextField: View {

    @Bindable var graph: GraphState
    let titleEditType: StitchTitleEdit
    let label: String
    var font: Font = STITCH_FONT
    
    @MainActor
    var isFocused: Bool {
        graph.graphUI.reduxFocusedField?.getNodeTitleEdit == titleEditType
    }

    var body: some View {
        Group {
            if isFocused {
                StitchTextEditingField(
                    currentEdit: label, // starts out as `label`
                    fieldType: .nodeTitle(titleEditType),
                    shouldFocus: false,
                    isForNodeTitle: true,
                    font: font,
                    fontColor: Color(.nodeTitleFont)) { newEdit, isCommitting in
                        dispatch(NodeTitleEdited(titleEditType: titleEditType,
                                                 edit: newEdit,
                                                 isCommitting: isCommitting))
                    }
                    .frame(height: NODE_TITLE_HEIGHT,
                           alignment: .center)
                
#if targetEnvironment(macCatalyst)
//.offset(y: -1)  // Matches y axis for read-only string--only needed for Catalyst
                    .offset(y: -0.5)  // Matches y axis for read-only string--only needed for Catalyst
#endif
//                    .border(.green)
            } else {
                StitchTextView(string: label,
                               font: font)
                    .frame(height: NODE_TITLE_HEIGHT,
                           alignment: .center)
                   //  .border(.blue)
                // Manually focus this field when user taps.
                // Better as global redux-state than local view-state: only one field in entire app can be focused at a time.
                .onTapGesture {
                    // log("NodeTitleTextField tapped")
                    dispatch(ReduxFieldFocused(focusedField: .nodeTitle(titleEditType)))
                }
            }
        }
        .frame(minWidth: 20)
    }
}
