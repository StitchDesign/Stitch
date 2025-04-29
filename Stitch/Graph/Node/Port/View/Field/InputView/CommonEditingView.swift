//
//  CommonEditingView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/25/22.
//

import SwiftUI
import StitchSchemaKit

// Used for single-field portvalues like .number or .text,
// and as a single editable field for a multifield portvalues like .size
// Only used directly by input fields, not NodeTitleView etc.
struct CommonEditingView: View {
    
    // MARK: ENVIRONMENT STATE
    
    @Environment(\.appTheme) var theme
    
    // TODO: APRIL 29: remove? is this still relevant?
    @Environment(\.isSelectionBoxInUse) private var isSelectionBoxInUse
        
    
    // MARK: PASSED-IN VIEW PARAMETERS
    
    @Bindable var inputField: InputFieldViewModel
    
    let inputString: String
    
    @Bindable var graph: GraphState
    @Bindable var document: StitchDocumentViewModel
    
    let rowId: NodeRowViewModelId
    let layerInput: LayerInputPort?
        
    var fieldIndex: Int {
        inputField.fieldIndex
    }
    
    // Only for field-types that use a "TextField + Dropdown" view,
    // e.g. `LayerDimension`
    var choices: [String]?  = nil // ["fill", "auto"]

    var isLargeString: Bool = false
    
    let isForLayerInspector: Bool
    let isPackedLayerInputAlreadyOnCanvas: Bool
    
    // inspector only?
    let isFieldInMultifieldInput: Bool
    
    let isForFlyout: Bool
    let isForSpacingField: Bool
    let isSelectedInspectorRow: Bool // always false for canvas
    let hasHeterogenousValues: Bool // for layer multiselect
    
    // also inspector-only ?
    // TODO: APRIL 29
    let isFieldInMultifieldInspectorInputAndNotFlyout: Bool
    
    let fieldWidth: CGFloat

    
    // If we're not for the inspector or a flyout,
    // then assume we're on the canvas.
    var isCanvasField: Bool {
//        !isForLayerInspector && !isForFlyout
        inputField.id.rowId.graphItemType.getCanvasItemId.isDefined
    }
    
    
    // MARK: LOCAL VIEW STATE
 
#if DEV_DEBUG
    @State private var currentEdit = "no entry"
#else
    @State private var currentEdit = ""
#endif
    
    @State private var isBase64 = false
    
    // Only relevant for fields on canvas
    @State var isHovering: Bool = false
    
    // Only relevant for LahyerDimension fields, for `auto`, `fill`
    @State var pickerChoice: String = ""
    
    var body: some View {
        Group {
            if let choices = choices, self.hasPicker {
                textFieldViewWithPicker(choices)
            } else {
                textFieldView
            }
        }
        
        // TODO: put this common logic (.onAppear, .onChange) into a view modifier?
        
        // TODO: why is `.onChange(of: showEditingView)` not enough for a field focused in a flyout from an inspector-field click ?
        // For now, we want `initial: true` when we first focus a field
        .onChange(of: self.showEditingView, initial: true) { _, newValue in
            // Fixes beach balls for base 64 strings
            if newValue { self.updateCurrentEdit() }
        }
        .onChange(of: self.hasHeterogenousValues, initial: true) { oldValue, newValue in
            if newValue { self.updateCurrentEdit() }
        }
        .onHover { isHovering in
            // Ignore multifield hover
            guard self.multifieldLayerInput == nil else { return }
            self.isHovering = isHovering
        }
    }
    
    // CONTROLS SWITCHING BETWEEN EDITABLE VS READ-ONLY TEXT
    // For perf: we don't want the TextField rendering at all if not currently focused
    @ViewBuilder @MainActor
    var textFieldView: some View {
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
                                      fieldEditCallback: inputEditedCallback,
                                      isBase64: isBase64)
        .onDisappear {
            // Fixes issue where default false values aren't shown after clearing inputs
            self.currentEdit = self.inputString
            
            // Fixes issue where edits sometimes don't save if focus is lost
            if self.currentEdit != self.inputString {
                self.inputEditedCallback(newEdit: self.currentEdit,
                                         isCommitting: true)
            }
        }
        
#if targetEnvironment(macCatalyst)
        .offset(y: -0.5) // slight adjustment required
#endif
        
        .modifier(InputFieldBackground(
            show: true, // always show background for a focused input
            hasDropdown: self.hasPicker,
            forPropertySidebar: isForLayerInspector,
            isSelectedInspectorRow: isSelectedInspectorRow,
            width: fieldWidth,
            isHovering: isHovering,
            onTap: nil))
        
        // Field highlight
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .stroke(theme.themeData.edgeColor,
                        // Color.accentColor,
                        lineWidth: self.showEditingView ? 2 : 0)
        }
    } // editableTextFieldView
}



// MARK: READ-ONLY VIEW

extension CommonEditingView {
    @MainActor
    var readOnlyTextView: some View {
        // If can tap to edit, and this is a number field,
        // then bring up the number-adjustment-bar first;
        // for multifields now, the editType value is gonna be a parentValue of eg size or position
        CommonEditingViewReadOnly(
            inputField: inputField,
            inputString: inputString,
            forPropertySidebar: isForLayerInspector,
            isHovering: isHovering,
            choices: choices,
            fieldWidth: fieldWidth,
            fieldHasHeterogenousValues: hasHeterogenousValues,
            isSelectedInspectorRow: isSelectedInspectorRow,
            isFieldInMultfieldInspectorInput: isFieldInMultifieldInspectorInputAndNotFlyout,
            onTap: {
                // Every multifield input in the inspector uses a flyout
                if isFieldInMultifieldInspectorInputAndNotFlyout,
                   let layerInput = layerInput,
                   !isForFlyout {
                    dispatch(FlyoutToggled(flyoutInput: layerInput,
                                           flyoutNodeId: nodeId,
                                           fieldToFocus: .textInput(id)))
                } else {
                    dispatch(ReduxFieldFocused(focusedField: .textInput(id)))
                }
            })
    }
}


// MARK: PICKER

extension CommonEditingView {
            
    func textFieldViewWithPicker(_ choices: [String]) -> some View {
        HStack(spacing: 0) {
            textFieldView
            /*
             Important: must .overlay `picker` on a view that does not change when field is focused/defocused.
             
             `HStack { textFieldView, picker }` introduces alignment issues from picker's SwiftUI Menu/Picker
             
             `textFieldView.overlay { picker }` causes picker to flash when the underlying text-field / read-only-text view is changed via if/else.
             */
            Rectangle().fill(.clear).frame(width: 1, height: 1)
                .overlay {
                    layerDimensionPicker(choices)
                        .offset(x: -COMMON_EDITING_DROPDOWN_CHEVRON_WIDTH/2)
                        .offset(x: -2) // "padding"
                }
        }
    }
    
    // Note: currently only used for LayerDimension `fill` and `auto` cases
    @MainActor
    func layerDimensionPicker(_ choices: [String]) -> some View {
        Menu {
            Picker("", selection: $pickerChoice) {
                ForEach(self.choices ?? [], id: \.self) {
                    Text($0)
                }
            }
        } label: {
            Image(systemName: "chevron.down")
                .resizable()
                .frame(width: COMMON_EDITING_DROPDOWN_CHEVRON_WIDTH,
                       height: COMMON_EDITING_DROPDOWN_CHEVRON_HEIGHT)
                .padding(8) // increase hit area
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
        .onChange(of: self.pickerChoice, initial: false) { oldValue, newValue in
            if let _ = self.choices?.first(where: { $0 == newValue }) {
                // log("on change of choice: valid new choice")
                self.currentEdit = newValue
                self.inputEditedCallback(newEdit: newValue,
                                         isCommitting: true)
            }
        }
        
        // When text-field's string edited to be an exact match for a dropdown item, update the dropdown's selection.
        .onChange(of: self.currentEdit) { oldValue, newValue in
            if let x = self.choices?.first(where: { $0.lowercased() == self.currentEdit.lowercased() }) {
                // log("found choice \(x)")
                self.pickerChoice = x
            }
        }
    } // var layerDimensionPicker
}


// MARK: DERIVED

extension CommonEditingView {
    
    var id: FieldCoordinate {
        self.inputField.id
    }
    
    var nodeId: NodeId {
        self.id.rowId.nodeId
    }
    
    // Important perf check to prevent instantiations of editing view
    @MainActor
    var showEditingView: Bool {
        // Can never focus the field of property row if that propery is already on the graph
        if isForLayerInspector && isPackedLayerInputAlreadyOnCanvas {
            // log("CommonEditingView: will not focus because already on graph; field index \(self.fieldIndex) of field coordinate \(id) on node \(nodeId)")
            return false
        }
        
        // Can never focus the field of a multifield input (must happen via flyout)
        if isForLayerInspector && isFieldInMultifieldInspectorInputAndNotFlyout {
            return false
        }
                
        if isForLayerInspector {
            return isThisFieldFocused
        } else {
            return isThisFieldFocused && !isSelectionBoxInUse
        }
    }
    
    @MainActor
    var isThisFieldFocused: Bool {
        switch document.reduxFocusedField {
        case .textInput(let focusedFieldCoordinate):
            let k = focusedFieldCoordinate == id
            // log("CommonEditingView: thisFieldIsFocused: k: \(k) for \(fieldCoordinate)")
            return k
        default:
            // log("CommonEditingView: thisFieldIsFocused: false")
            return false
        }
    }
    
    var hasPicker: Bool {
        choices.isDefined && !isFieldInMultifieldInspectorInputAndNotFlyout
    }
    
    var multifieldLayerInput: LayerInputPort? {
        isFieldInMultifieldInspectorInputAndNotFlyout ? self.layerInput : nil
    }
}


// MARK: METHODS

extension CommonEditingView {
    // Currently only used when we focus or de-focus
    @MainActor
    func updateCurrentEdit(message: String? = nil) {
        
        if self.hasHeterogenousValues {
            self.currentEdit = .HETEROGENOUS_VALUES
        } else {
            self.currentEdit = isLargeString ? "" : self.inputString
        }
            
        self.isBase64 = isLargeString
        
        // update the picker choice as user types?
        // so that e.g. if they type away from "auto", the picker will be blank / none / de-selected option
        
        // TODO: how to handle this dropdown when we have multiple layers selected?
        self.pickerChoice = isLargeString ? "" : self.inputString
    }

    // fka `createInputEditAction`
    @MainActor func inputEditedCallback(newEdit: String,
                                        isCommitting: Bool) {
        self.graph.inputEditedFromUI(
            fieldValue: .string(.init(newEdit)),
            fieldIndex: self.fieldIndex,
            rowId: self.rowId,
            activeIndex: document.activeIndex,
            isFieldInsideLayerInspector: self.isForLayerInspector,
            isCommitting: isCommitting)
    }
}
