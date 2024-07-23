//
//  CommonEditingView.swift
//  prototype
//
//  Created by Christian J Clampitt on 2/25/22.
//

import SwiftUI
import StitchSchemaKit

let COMMON_EDITING_DROPDOWN_CHEVRON_WIDTH = 12.0
let COMMON_EDITING_DROPDOWN_CHEVRON_HEIGHT = COMMON_EDITING_DROPDOWN_CHEVRON_WIDTH - 4.0

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

    // Only for field-types that use a "TextField + Dropdown" view,
    // e.g. `LayerDimension`
    var choices: [String]? = nil // ["fill", "auto"]

    var isAdjustmentBarInUse: Bool = false
    var isLargeString: Bool = false
    
    let forPropertySidebar: Bool
    let propertyIsAlreadyOnGraph: Bool
    
    var id: FieldCoordinate {
        self.inputField.id
    }

    @State var isHovering: Bool = false
    
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

//    let choices: [String]? = ["auto", "fill", "hug"]
//    let choices: [String]? = nil
    
    var body: some View {
        Group {
            if let choices = choices {
                
                HStack(spacing: 0) {
                    
                    textFieldView
                    
                    /*
                     Important: must .overlay `picker` on a view that does not change when field is focused/defocused.
                     
                     `HStack { textFieldView, picker }` introduces alignment issues from picker's SwiftUI Menu/Picker
                     
                     `textFieldView.overlay { picker }` causes picker to flash when the underlying text-field / read-only-text view is changed via if/else.
                     */
                    Rectangle().fill(.clear).frame(width: 1, height: 1)
                        .overlay {
                            picker(choices)
                                .offset(x: -COMMON_EDITING_DROPDOWN_CHEVRON_WIDTH/2)
                                .offset(x: -2) // "padding"
                        }
                }
                
            } else {
                textFieldView
            }
        }
        .onChange(of: showEditingView) { _, newValue in
            // Fixes beach balls for base 64 strings
            if showEditingView {
                self.updateCurrentEdit()
            }
        }
        .onHover { isHovering in
            withAnimation {
                self.isHovering = isHovering
            }
        }
    }
    
    @State var choice: String = ""
        
    @MainActor
    func picker(_ choices: [String]) -> some View {
        Menu {
            Picker("", selection: $choice) {
                ForEach(self.choices ?? [], id: \.self) {
                    Text($0)
                }
            }
        } label: {
            Image(systemName: "chevron.down")
                .resizable()
                .frame(width: COMMON_EDITING_DROPDOWN_CHEVRON_WIDTH,
                       height: COMMON_EDITING_DROPDOWN_CHEVRON_HEIGHT)
        }
        
        // TODO: why must we hide the native menuIndicator?
        .menuIndicator(.hidden) // hides caret indicator
        
#if targetEnvironment(macCatalyst)
        .menuStyle(.button)
        .buttonStyle(.plain) // fixes Catalyst accent-color issue
        .foregroundColor(STITCH_FONT_GRAY_COLOR)
        .pickerStyle(.inline) // avoids unnecessary middle label
#endif

        // When dropdown item selected, update text-field's string
        .onChange(of: self.choice) { oldValue, newValue in
            log("new choice \(newValue)")
            self.currentEdit = newValue
            self.inputEdited(newEdit: newValue,
                             isCommitting: true)
        }
        
        // When text-field's string edited to be an exact match for a dropdown item, update the dropdown's selection.
        .onChange(of: self.currentEdit) { oldValue, newValue in
            if let x = self.choices?.first(where: { $0 == self.currentEdit }) {
                log("found choice \(x)")
                self.choice = x
            }
        }
    } // var picker: ...
    
    @ViewBuilder @MainActor
    var textFieldView: some View {
        // For perf: we don't want this view rendering at all if not currently focused
        if showEditingView {
            editableTextFieldView
        } else {
           readOnlyTextView
        }
    }
    
    @MainActor
    var editableTextFieldView: some View {
        // logInView("CommonEditView: if: fieldCoordinate: \(fieldCoordinate)")
        
        // Render NodeTextFieldView if its the focused field.
        StitchTextEditingBindingField(currentEdit: $currentEdit,
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
                self.inputEdited(newEdit: self.currentEdit,
                                 isCommitting: true)
            }
        }
        
#if targetEnvironment(macCatalyst)
        .offset(y: -0.5) // slight adjustment required
#endif
        .modifier(InputViewBackground(
            backgroundColor: Self.editableTextFieldBackgroundColor,
            show: true, // always show background for a focused input
            hasDropdown: choices.isDefined))
    }
    
    @MainActor
    var readOnlyTextView: some View {
        // If can tap to edit, and this is a number field,
        // then bring up the number-adjustment-bar first;
        // for multifields now, the editType value is gonna be a parentValue of eg size or position
        StitchTextView(string: self.inputString, // pointing to currentEdit fixes jittery updates
                       font: STITCH_FONT,
                       fontColor: STITCH_FONT_GRAY_COLOR)
        .modifier(InputViewBackground(
            backgroundColor: Self.readOnlyTextBackgroundColor,
            show: self.isHovering,
            hasDropdown: choices.isDefined))
        // Manually focus this field when user taps.
        // Better as global redux-state than local view-state: only one field in entire app can be focused at a time.
        .onTapGesture {
            dispatch(ReduxFieldFocused(focusedField: .textInput(id)))
        }
    }
    
    #if DEV_DEBUG
    static let readOnlyTextBackgroundColor: Color = .blue.opacity(0.5)
    static let editableTextFieldBackgroundColor: Color = .green.opacity(0.5)
    #else
    static let readOnlyTextBackgroundColor: Color = INPUT_FIELD_BACKGROUND
    static let editableTextFieldBackgroundColor: Color = INPUT_FIELD_BACKGROUND
    #endif
    
    // Currently only used when we focus or de-focus
    func updateCurrentEdit() {
        self.currentEdit = isLargeString ? "" : self.inputString
        self.isBase64 = isLargeString
        
        // update the picker choice as user types?
        // so that e.g. if they type away from "auto", the picker will be blank / none / de-selected option
        self.choice = isLargeString ? "" : self.inputString
    }

    // fka `createInputEditAction`
    @MainActor func inputEdited(newEdit: String,
                                isCommitting: Bool) {
        if let coordinate = self.inputField.rowViewModelDelegate?.rowDelegate?.id {
            self.graph.inputEdited(
                fieldValue: .string(.init(newEdit)),
                fieldIndex: fieldIndex,
                coordinate: coordinate,
                isCommitting: isCommitting)
        }
    }
}

// TODO: per Elliot, this is actually a perf-expensive view?
struct InputViewBackground: ViewModifier {
    
    var backgroundColor: Color
    let show: Bool // if hovering or selected
    let hasDropdown: Bool
    
    func body(content: Content) -> some View {
        content
        
        // When this field uses a dropdown,
        // we shrink the "typeable" area of the input,
        // so that typing never touches the dropdown's menu indicator.
            .frame(width: NODE_INPUT_OR_OUTPUT_WIDTH - (hasDropdown ? (COMMON_EDITING_DROPDOWN_CHEVRON_WIDTH + 2) : 0.0),
                   alignment: .leading)
        
        // ... But we always use a full-width background for the focus/hover effect.
            .frame(width: NODE_INPUT_OR_OUTPUT_WIDTH,
                   alignment: .leading)
            .padding([.leading, .top, .bottom], 2)
            .background {
                let color = show ? backgroundColor : .clear
                RoundedRectangle(cornerRadius: 4).fill(color)
            }
            .contentShape(Rectangle())
    }
}
