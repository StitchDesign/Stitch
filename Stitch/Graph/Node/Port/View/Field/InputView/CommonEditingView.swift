//
//  CommonEditingView.swift
//  prototype
//
//  Created by Christian J Clampitt on 2/25/22.
//

import SwiftUI
import StitchSchemaKit

// node field input/output width, per Figma Spec
let NODE_INPUT_OR_OUTPUT_WIDTH: CGFloat = 56

// Used for single-field portvalues like .number or .text,
// and as a single editable field for a multifield portvalues like .size
// Only used directly by input fields, not NodeTitleView etc.
struct CommonEditingView: View {
    @Environment(\.isSelectionBoxInUse) private var isSelectionBoxInUse
        
    @State private var currentEdit = ""
    @State private var isBase64 = false
    
    @Bindable var inputField: InputFieldViewModel
    let inputString: String
    @Bindable var graph: GraphState
    let fieldIndex: Int
    let isCanvasItemSelected: Bool
    let hasIncomingEdge: Bool
    var isAdjustmentBarInUse: Bool = false
    var isLargeString: Bool = false

    let forPropertySidebar: Bool // = false
    let propertyIsAlreadyOnGraph: Bool
    
    var id: FieldCoordinate {
        self.inputField.id
    }

    // Important perf check to prevent instantiations of editing view
    @MainActor
    var showEditingView: Bool {
        // Can never focus the field of property row if that propery is already on the graph
        if forPropertySidebar && propertyIsAlreadyOnGraph {
            return false
        }
        
        if forPropertySidebar {
           return thisFieldIsFocused
        } else {
            return thisFieldIsFocused && isCanvasItemSelected && !isSelectionBoxInUse
        }
    }
    
    @MainActor
    var thisFieldIsFocused: Bool {
        switch graph.graphUI.reduxFocusedField {
        case .textInput(let focusedFieldCoordinate):
            let k = focusedFieldCoordinate == id
//             log("CommonEditingView: thisFieldIsFocused: k: \(k) for \(fieldCoordinate)")
            return k
        default:
            // log("CommonEditingView: thisFieldIsFocused: false")
            return false
        }
    }

    var body: some View {
        Group {
            // For perf: we don't want this view rendering at all if not currently focused
            if showEditingView {
                // logInView("CommonEditView: if: fieldCoordinate: \(fieldCoordinate)")
                
                // Render NodeTextFieldView if its the focused field.
                StitchTextEditingBindingField(
                    currentEdit: $currentEdit,
                    fieldType: .textInput(id),
                    font: STITCH_FONT,
                    fontColor: STITCH_FONT_GRAY_COLOR,
                    fieldEditCallback: inputEdited,
                    isBase64: isBase64)
                    .onDisappear {
                        // Fixes issue where default false values aren't shown after clearing inputs
                        self.currentEdit = self.inputString

                        // Fixes issue where edits sometimes don't save if focus is lost
                        if self.currentEdit != self.inputString {
                            self.inputEdited(
                                newEdit: self.currentEdit,
                                isCommitting: true)
                        }
                    }

                #if targetEnvironment(macCatalyst)
                    .offset(y: -0.5) // slight adjustment required
                #endif
                    .modifier(InputViewBackground(backgroundColor: Self.editableTextFieldBackgroundColor))                   
            } else {
                // If can tap to edit, and this is a number field,
                // then bring up the number-adjustment-bar first;
                // for multifields now, the editType value is gonna be a parentValue of eg size or position
                StitchTextView(string: self.inputString, // pointing to currentEdit fixes jittery updates
                               font: STITCH_FONT,
                               fontColor: STITCH_FONT_GRAY_COLOR)
                .modifier(InputViewBackground(backgroundColor: Self.readOnlyTextBackgroundColor))
                // Manually focus this field when user taps.
                // Better as global redux-state than local view-state: only one field in entire app can be focused at a time.
                .onTapGesture {
                    dispatch(ReduxFieldFocused(focusedField: .textInput(id)))
                }
            }
        }
        .onChange(of: showEditingView) { _, newValue in
            // Fixes beach balls for base 64 strings
            if showEditingView {
                self.updateCurrentEdit()
            }
        }
    }
    
    #if DEV_DEBUG
    static let readOnlyTextBackgroundColor: Color = .blue.opacity(0.5)
    static let editableTextFieldBackgroundColor: Color = .green.opacity(0.5)
    #else
    static let readOnlyTextBackgroundColor: Color = INPUT_FIELD_BACKGROUND
    static let editableTextFieldBackgroundColor: Color = INPUT_FIELD_BACKGROUND
    #endif
    
    func updateCurrentEdit() {
        self.currentEdit = isLargeString ? "" : self.inputString
        self.isBase64 = isLargeString
    }

    // fka `createInputEditAction`
    @MainActor func inputEdited(newEdit: String,
                     isCommitting: Bool) {
        self.graph.inputEdited(
            fieldValue: .string(.init(newEdit)),
            fieldIndex: fieldIndex,
            inputField: inputField,
            isCommitting: isCommitting)
    }
}

// TODO: per Elliot, this is actually a perf-expensive view?
struct InputViewBackground: ViewModifier {
    
    var backgroundColor: Color
    
    func body(content: Content) -> some View {
        content
            .frame(width: NODE_INPUT_OR_OUTPUT_WIDTH,
                   alignment: .leading)
            .padding([.leading, .top, .bottom], 2)
            .background {
                RoundedRectangle(cornerRadius: 4).fill(backgroundColor)
            }
            .contentShape(Rectangle())
    }
}
