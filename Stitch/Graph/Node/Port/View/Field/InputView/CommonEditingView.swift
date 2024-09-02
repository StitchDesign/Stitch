//
//  CommonEditingView.swift
//  prototype
//
//  Created by Christian J Clampitt on 2/25/22.
//

import SwiftUI
import StitchSchemaKit

extension Color {
    static let BLACK_IN_LIGHT_MODE_WHITE_IN_DARK_MODE: Color = Color(.lightModeBlackDarkModeWhite)
    
    static let WHITE_IN_LIGHT_MODE_BLACK_IN_DARK_MODE: Color = Color(.lightModeWhiteDarkModeBlack)
    
    static let INSPECTOR_FIELD_BACKGROUND_COLOR = Color(.inspectorFieldBackground)
    
#if DEV_DEBUG
    static let COMMON_EDITING_VIEW_READ_ONLY_BACKGROUND_COLOR: Color = .blue.opacity(0.5)
    static let COMMON_EDITING_VIEW_EDITABLE_FIELD_BACKGROUND_COLOR: Color = .green.opacity(0.5)
#else
    static let COMMON_EDITING_VIEW_READ_ONLY_BACKGROUND_COLOR: Color = INPUT_FIELD_BACKGROUND
    static let COMMON_EDITING_VIEW_EDITABLE_FIELD_BACKGROUND_COLOR: Color = INPUT_FIELD_BACKGROUND
#endif
}

let COMMON_EDITING_DROPDOWN_CHEVRON_WIDTH = 12.0
let COMMON_EDITING_DROPDOWN_CHEVRON_HEIGHT = COMMON_EDITING_DROPDOWN_CHEVRON_WIDTH - 4.0

// node field input/output width, per Figma Spec
let NODE_INPUT_OR_OUTPUT_WIDTH: CGFloat = 56

let TEXT_FONT_DROPDOWN_WIDTH: CGFloat = 200
//let SPACING_FIELD_WIDTH: CGFloat = 72
//let SPACING_FIELD_WIDTH: CGFloat = 70
let SPACING_FIELD_WIDTH: CGFloat = 68
let PADDING_FIELD_WDITH: CGFloat = 36

// TODO: alternatively, allow these fields to size themselves?
let INSPECTOR_MULTIFIELD_INDIVIDUAL_FIELD_WIDTH: CGFloat = 44

// Used for single-field portvalues like .number or .text,
// and as a single editable field for a multifield portvalues like .size
// Only used directly by input fields, not NodeTitleView etc.
struct CommonEditingView: View {
    @Environment(\.isSelectionBoxInUse) private var isSelectionBoxInUse
    
    @State private var currentEdit = ""
    @State private var isBase64 = false
    
    @Bindable var inputField: InputFieldViewModel
    let inputLayerNodeRowData: InputLayerNodeRowData?
    
    let inputString: String // from redux
    
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
    let isFieldInMultifieldInput: Bool
    let isForFlyout: Bool
    let isForSpacingField: Bool
    let isSelectedInspectorRow: Bool
    
    let isFieldInMultfieldInspectorInput: Bool
    let fieldWidth: CGFloat
    
    var id: FieldCoordinate {
        self.inputField.id
    }
    
    var nodeId: NodeId {
        self.id.rowId.nodeId
    }

    // Only relevant for fields on canvas
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
            // log("CommonEditingView: thisFieldIsFocused: k: \(k) for \(fieldCoordinate)")
            return k
        default:
            // log("CommonEditingView: thisFieldIsFocused: false")
            return false
        }
    }
    
    var isFieldInsideLayerInspector: Bool {
        inputField.isFieldInsideLayerInspector
    }

    var layerInput: LayerInputPort? {
        inputField.layerInput
    }
    
    @MainActor
    var multiselectInputs: LayerInputTypeSet? {
        graph.graphUI.propertySidebar.inputsCommonToSelectedLayers
    }
            
    @MainActor
    var fieldHasHeterogenousValues: Bool {
        if let inputLayerNodeRowData = inputLayerNodeRowData {
            @Bindable var inputLayerNodeRowData = inputLayerNodeRowData
            return inputLayerNodeRowData.fieldHasHeterogenousValues(
                fieldIndex,
                isFieldInsideLayerInspector: isFieldInsideLayerInspector)
        } else {
            return false
        }
    }
    
    var body: some View {
        Group {
            // Show dropdown
            if let choices = choices, !isFieldInMultfieldInspectorInput {
                
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
        .onChange(of: self.fieldHasHeterogenousValues, initial: true) { oldValue, newValue in
            // log("CommonEditingView: on change of: self.hasHeterogenousValues: id: \(id)")
            // log("CommonEditingView: on change of: self.hasHeterogenousValues: oldValue: \(oldValue)")
            // log("CommonEditingView: on change of: self.hasHeterogenousValues: newValue: \(newValue)")
            if newValue {
                // log("CommonEditingView: on change of: self.hasHeterogenousValues: had multi")
                self.updateCurrentEdit()
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

        // TODO: this fires as soon as the READ-ONLY view is rendered, which we don't want.
        // When dropdown item selected, update text-field's string
        .onChange(of: self.choice, initial: false) { oldValue, newValue in
            if let _ = self.choices?.first(where: { $0 == newValue }) {
                // log("on change of choice: valid new choice")
                self.currentEdit = newValue
                self.inputEdited(newEdit: newValue,
                                 isCommitting: true)
            }
        }
        
        // When text-field's string edited to be an exact match for a dropdown item, update the dropdown's selection.
        .onChange(of: self.currentEdit) { oldValue, newValue in
            if let x = self.choices?.first(where: { $0.lowercased() == self.currentEdit.lowercased() }) {
                // log("found choice \(x)")
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
            show: true, // always show background for a focused input
            hasDropdown: choices.isDefined,
            forPropertySidebar: forPropertySidebar,
            isSelectedInspectorRow: isSelectedInspectorRow,
            width: fieldWidth))
    }
        
        
    @MainActor
    var readOnlyTextView: some View {
        // If can tap to edit, and this is a number field,
        // then bring up the number-adjustment-bar first;
        // for multifields now, the editType value is gonna be a parentValue of eg size or position
        CommonEditingViewReadOnly(
            inputField: inputField,
            inputString: inputString,
            forPropertySidebar: forPropertySidebar,
            isHovering: isHovering,
            choices: choices,
            fieldWidth: fieldWidth,
            fieldHasHeterogenousValues: fieldHasHeterogenousValues,
            isSelectedInspectorRow: isSelectedInspectorRow, 
            onTap: {
                // Every multifield input in the inspector uses a flyout
                if isFieldInMultfieldInspectorInput,
                   let layerInput = inputField.layerInput,
                   !isForFlyout {
                    dispatch(FlyoutToggled(flyoutInput: layerInput,
                                           flyoutNodeId: nodeId))
                } else {
                    dispatch(ReduxFieldFocused(focusedField: .textInput(id)))
                }
                
            })
        
        
//        StitchTextView(string: self.fieldHasHeterogenousValues ? .HETEROGENOUS_VALUES : self.inputString,
//                       font: STITCH_FONT,
//                       fontColor: STITCH_FONT_GRAY_COLOR)
//        .modifier(InputViewBackground(
//            backgroundColor: forPropertySidebar ? .INSPECTOR_FIELD_BACKGROUND_COLOR : .COMMON_EDITING_VIEW_READ_ONLY_BACKGROUND_COLOR,
//            show: self.isHovering || forPropertySidebar,
//            hasDropdown: choices.isDefined,
//            width: fieldWidth))
//        
//        // Manually focus this field when user taps.
//        // Better as global redux-state than local view-state: only one field in entire app can be focused at a time.
//        .onTapGesture {
//            // Every multifield input in the inspector uses a flyout
//            if isFieldInMultfieldInspectorInput,
//               let layerInput = inputField.layerInput,
//               !isForFlyout {
//                
//                dispatch(FlyoutToggled(flyoutInput: layerInput,
//                                       flyoutNodeId: self.nodeId))
//            } else {
//                dispatch(ReduxFieldFocused(focusedField: .textInput(id)))
//            }
//        }
        
    }
    
//    var isFieldInMultfieldInspectorInput: Bool {
////        isFieldInMultifieldInput && forPropertySidebar
//        isFieldInMultifieldInput
//        && forPropertySidebar
//        && !isForFlyout
//        
//    }
    
//    var fieldWidth: CGFloat {
//        
//        if isFieldInMultfieldInspectorInput {
//            return INSPECTOR_MULTIFIELD_INDIVIDUAL_FIELD_WIDTH
//        }
//        
//        if isForSpacingField {
//            return SPACING_FIELD_WIDTH
//        }
//        
//        return NODE_INPUT_OR_OUTPUT_WIDTH
//    }

    // Currently only used when we focus or de-focus
    @MainActor
    func updateCurrentEdit(message: String? = nil) {
        
        if self.fieldHasHeterogenousValues {
            self.currentEdit = .HETEROGENOUS_VALUES
        } else {
            self.currentEdit = isLargeString ? "" : self.inputString
        }
            
        self.isBase64 = isLargeString
        
        // update the picker choice as user types?
        // so that e.g. if they type away from "auto", the picker will be blank / none / de-selected option
        
        // TODO: how to handle this dropdown when we have multiple layers selected?
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
                isFieldInsideLayerInspector: self.isFieldInsideLayerInspector,
                isCommitting: isCommitting)
        }
    }
}

// TODO: per Elliot, this is actually a perf-expensive view?
struct InputViewBackground: ViewModifier {
    
    @Environment(\.appTheme) var theme
    
//    var backgroundColor: Color
    let show: Bool // if hovering, selected or for sidebar
    let hasDropdown: Bool
    let forPropertySidebar: Bool
    let isSelectedInspectorRow: Bool
    var width: CGFloat? // nil for a field inside a multifield input in the inspector
    
    var finalWidth: CGFloat? {
        if let width = width {
            return width - (hasDropdown ? (COMMON_EDITING_DROPDOWN_CHEVRON_WIDTH + 2) : 0.0)
        }
        return nil
    }
    
    var backgroundColor: Color {
        if forPropertySidebar {
            return Color.INSPECTOR_FIELD_BACKGROUND_COLOR
        } else {
            return Color.COMMON_EDITING_VIEW_READ_ONLY_BACKGROUND_COLOR
        }
    }
    
    func body(content: Content) -> some View {
        content
        
        // When this field uses a dropdown,
        // we shrink the "typeable" area of the input,
        // so that typing never touches the dropdown's menu indicator.
            .frame(width: finalWidth,
                   alignment: .leading)
        
        // ... But we always use a full-width background for the focus/hover effect.
            .frame(width: finalWidth,
                   alignment: .leading)
            .padding([.leading, .top, .bottom], 2)
            .background {
                // Why is `RoundedRectangle.fill` so much lighter than `RoundedRectangle.background` ?
                let color = show ? backgroundColor : Color.clear
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .overlay {
                        if isSelectedInspectorRow {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(theme.fontColor.opacity(0.3))
                        }
                    }
            }
            .contentShape(Rectangle())
    }
}


