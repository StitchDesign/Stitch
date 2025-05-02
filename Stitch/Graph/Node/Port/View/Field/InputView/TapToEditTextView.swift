//
//  TapToEditTextView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/29/25.
//

import SwiftUI

/*
 A common view for directly editable input-fields that accept alphanumeric input.
 
 Intended for input-fields, not e.g. canvas item title fields.
 
 SwiftUI's TextField is very CPU-intensive, even when not focused.
 Therefore we render Text unless this specific field is focused.
 */
struct TapToEditTextView: View {
    
    // MARK: ENVIRONMENT STATE
    
    @Environment(\.appTheme) var theme
            

    // MARK: PASSED-IN VIEW PARAMETERS

    @Bindable var document: StitchDocumentViewModel
    
    @Bindable var inputField: InputFieldViewModel
        
    let fieldWidth: CGFloat
                
    // Only for field-types that use a "TextField + Dropdown" view,
    let choices: [String]? // e.g. `LayerDimension` has ["fill", "auto"]
    let hasPicker: Bool
    
    // For Base64
    let isLargeString: Bool
    
    // For inspector and flyout only
    let isForLayerInspector: Bool
    let isPackedLayerInputAlreadyOnCanvas: Bool
    let isSelectedInspectorRow: Bool // always false for canvas
    let hasHeterogenousValues: Bool // for layer multiselect
    
    // Helps us know when tapping a field in inspector can open the flyout
    let isFieldInMultifieldInspectorInputAndNotFlyout: Bool
    
    // For canvas input fields only
    let isHovering: Bool
    @Binding var isCurrentlyFocused: Bool
    
    
    var onReadOnlyTap: () -> Void
        
    var inputString: String {
        inputField.fieldValue.stringValue
    }
    
    var rowId: NodeRowViewModelId {
        inputField.id.rowId
    }
    
    var isSelectionBoxInUse: Bool {
        self.document.visibleGraph.selection.isSelecting
    }
    
    
    // MARK: LOCAL VIEW STATE
 
#if DEV_DEBUG
    @State var currentEdit = "no entry"
#else
    @State var currentEdit = ""
#endif
    
    @State private var isBase64 = false
        
    // Only relevant for LayerDimension fields, for `auto`, `fill`
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
            self.isCurrentlyFocused = newValue
        }
        .onChange(of: self.hasHeterogenousValues, initial: true) { oldValue, newValue in
            if newValue { self.updateCurrentEdit() }
        }
    }
    
    // CONTROLS SWITCHING BETWEEN EDITABLE VS READ-ONLY TEXT
    // For perf: we don't want the TextField rendering at all if not currently focused
    @ViewBuilder @MainActor
    var textFieldView: some View {
        if showEditingView {
            editableTextFieldView
        } else {
            TapToEditReadOnlyView(
                inputString: inputString,
                fieldWidth: fieldWidth,
                isFocused: false,
                isHovering: isHovering,
                isForLayerInspector: isForLayerInspector,
                hasPicker: hasPicker,
                fieldHasHeterogenousValues: hasHeterogenousValues,
                isSelectedInspectorRow: isSelectedInspectorRow,
                onTap: onReadOnlyTap)
        }
    }
    
    @MainActor
    var editableTextFieldView: some View {
        // logInView("CommonEditView: if: fieldCoordinate: \(fieldCoordinate)")
        
        // Render NodeTextFieldView if its the focused field.
        StitchTextEditingBindingField(currentEdit: $currentEdit,
                                      fieldType: .textInput(self.fieldCoordinate),
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
        
        .modifier(InputFieldFrameAndPadding(
            width: fieldWidth,
            hasPicker: hasPicker))
        
        .modifier(InputFieldBackgroundColorView(
            isHovering: self.isHovering,
            isFocused: true,
            isForLayerInspector: isForLayerInspector,
            isSelectedInspectorRow: isSelectedInspectorRow))
        
        // Field highlight
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .stroke(theme.themeData.edgeColor,
                        // Color.accentColor,
                        lineWidth: self.showEditingView ? 2 : 0)
        }
    } // editableTextFieldView
}


// MARK: DERIVED

extension TapToEditTextView {
    
    var fieldCoordinate: FieldCoordinate {
        self.inputField.id
    }
        
    // TODO: can we create `InspectorCommonEditingView` (analogous to `CanvasCommonEditingView`) and avoid some of these checks? Get the view as small and as focused as possible.
    // TODO: perhaps we can pass this in like a function ?
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
            // TODO: Is the `!isSelectionBoxInUse` check still necessary?
            return isThisFieldFocused && !isSelectionBoxInUse
        }
    }
    
    @MainActor
    var isThisFieldFocused: Bool {
        switch document.reduxFocusedField {
        case .textInput(let focusedFieldCoordinate):
            let focused = focusedFieldCoordinate == self.fieldCoordinate
            // log("isThisFieldFocused: self.fieldCoordinate \(self.fieldCoordinate): focused: \(focused)")
            return focused
        default:
            // log("isThisFieldFocused: self.fieldCoordinate \(self.fieldCoordinate): NOT FOCUSED")
            return false
        }
    }
}


// MARK: METHODS

extension TapToEditTextView {
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
        
        self.document.visibleGraph.inputEditedFromUI(
            fieldValue: .string(.init(newEdit)),
            fieldIndex: self.inputField.fieldIndex,
            rowId: self.rowId,
            activeIndex: document.activeIndex,
            isFieldInsideLayerInspector: self.isForLayerInspector,
            isCommitting: isCommitting)
    }
}
