//
//  CanvasCommonEditingView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/29/25.
//

import SwiftUI


struct CanvasCommonEditingView: View {
    
    @Bindable var document: StitchDocumentViewModel
    
    @Bindable var inputField: InputFieldViewModel
        
    // Only for field-types that use a "TextField + Dropdown" view,
    // e.g. `LayerDimension`
    let choices: [String]? // = nil // ["fill", "auto"]
    
    let isLargeString: Bool
        
    let fieldWidth: CGFloat
    
    static let HOVER_EXTRA_LENGTH: CGFloat = 52
    
    var hoveringAdjustment: CGFloat {
        shouldShowExtendedField ? Self.HOVER_EXTRA_LENGTH : 0
    }
    
    
//    func onFingerTap() {
//        if !self.isHovering {
//            dispatch(ReduxFieldFocused(focusedField: .textInput(self.inputField.id)))
//        }
//    }
    
    func onTap() {
        dispatch(ReduxFieldFocused(focusedField: .textInput(self.inputField.id)))
    }
    
    // Canvas input fields that are hovered or actively-focused show more of their contents
    var shouldShowExtendedField: Bool {
        self.isHovering || self.isCurrentlyFocused
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
            self.isHovering = $0
        }
        
    }
}
