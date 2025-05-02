//
//  CanvasCommonEditingView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/29/25.
//

import SwiftUI


extension Color {
    static let EXTENDED_FIELD_BACKGROUND_COLOR: Self = .WHITE_IN_LIGHT_MODE_BLACK_IN_DARK_MODE
}

extension CGFloat {
    static let EXTENDED_FIELD_LENGTH: Self = 52
}

struct CanvasCommonEditingView: View {
    
    @Bindable var document: StitchDocumentViewModel
    
    @Bindable var inputField: InputFieldViewModel
        
    // Only for field-types that use a "TextField + Dropdown" view,
    // e.g. `LayerDimension`
    let choices: [String]? // = nil // ["fill", "auto"]
    
    let isLargeString: Bool
        
    let fieldWidth: CGFloat
    
    var hoveringAdjustment: CGFloat {
        shouldShowExtendedField ? .EXTENDED_FIELD_LENGTH : 0
    }
    
    func onTap() {
        dispatch(ReduxFieldFocused(focusedField: .textInput(self.inputField.id)))
    }
    
    // Canvas input fields that are hovered or actively-focused show more of their contents
    var shouldShowExtendedField: Bool {
        self.isHovering || self.isCurrentlyFocused || isThisFieldReduxFocused
    }
    
    @State private var isHovering = false
    
    @State var isCurrentlyFocused: Bool = false
        
    var body: some View {
        
        // The small-width read-only field shown in an input-field of a canvas item
        // Note: layer inputs can be on the canvas, but ignore multiselect
        TapToEditReadOnlyView(inputString: inputField.fieldValue.stringValue,
                              fieldWidth: fieldWidth,
                              isFocused: false,
                              isHovering: false,
                              isForLayerInspector: false,
                              
                              // The non-hovered canvas input field never shows picker
                              hasPicker: false,
                              
                              fieldHasHeterogenousValues: false,
                              isSelectedInspectorRow: false,
                              
                              // For canvas fields on iPad where hover may not be available (e.g. no trackpad),
                              // tap should focus the field.
                              onTap: self.onTap)
        .overlay {
            // TODO: show this even if we e.g. stop hovering but the field is focused
            if shouldShowExtendedField {
                TapToEditTextView(document: document,
                                  inputField: inputField,
                                  
                                  // The 'tap-to-edit' view shown in this hover-overlay should always have the wide-extension
                                  fieldWidth: fieldWidth + hoveringAdjustment,
                                  
                                  // Hovered canvas input field has picker just if choices are passed-in
                                  choices: choices,
                                  hasPicker: choices.isDefined,
                                  
                                  isLargeString: isLargeString,
                                  
                                  // None of the inspector/flyout conditions apply
                                  isForLayerInspector: false,
                                  isPackedLayerInputAlreadyOnCanvas: false,
                                  isSelectedInspectorRow: false,
                                  hasHeterogenousValues: false,
                                  isFieldInMultifieldInspectorInputAndNotFlyout: false,
                                  
                                  // Only for a canvas input field like this :-)
                                  isHovering: isHovering,
                                  isCurrentlyFocused: $isCurrentlyFocused,
                                  
                                  // Tapping the hovered read-only view should focus the field and show the edit view
                                  onReadOnlyTap: self.onTap)
                
                .offset(x: hoveringAdjustment / 2)
            }
        }
        .onHover {
            // If some other field is focused, this field can never be extended;
            // so turn off hovering and ignore future hovers.
            guard !isSomeOtherTextInputReduxFocused else {
                self.isHovering = false
                return
            }
            
            self.isHovering = $0
        }
        
        // If we defocus this field, immediately stop hovering
        .onChange(of: self.isThisFieldReduxFocused) { oldValue, newValue in
            if !newValue {
                self.isHovering = false
            }
        }
    }
    
    var isThisFieldReduxFocused: Bool {
        self.document.reduxFocusedField?.getTextInputEdit == inputField.id
    }
    
    var isSomeOtherTextInputReduxFocused: Bool {
        if let reduxFocusedTextField = self.document.reduxFocusedField?.getTextInputEdit {
            return reduxFocusedTextField != inputField.id
        }
        return false
    }
}
