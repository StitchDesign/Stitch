//
//  CanvasCommonEditingView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/29/25.
//

import SwiftUI


struct CanvasCommonEditingView: View {
    
    @Bindable var inputField: InputFieldViewModel
    
    let inputString: String
    
    @Bindable var graph: GraphState
    @Bindable var document: StitchDocumentViewModel
        
    // Only for field-types that use a "TextField + Dropdown" view,
    // e.g. `LayerDimension`
    let choices: [String]? // = nil // ["fill", "auto"]
    
    let isLargeString: Bool
    
    let isForFlyout: Bool
    
    // inspector only?
    let isFieldInMultifieldInput: Bool
    
    let isForSpacingField: Bool
    
    // also inspector-only ?
    // TODO: APRIL 29
    let isFieldInMultifieldInspectorInputAndNotFlyout: Bool
    
    let fieldWidth: CGFloat
    
        
    static let HOVER_EXTRA_LENGTH: CGFloat = 52
    
    var hoveringAdjustment: CGFloat {
        shouldShowExtendedField ? Self.HOVER_EXTRA_LENGTH : 0
    }
    
    // For canvas fields on iPad where hover may not be available (e.g. no trackpad),
    // tap should focus the field.
    func onFingerTap() {
        if !self.isHovering {
            dispatch(ReduxFieldFocused(focusedField: .textInput(self.inputField.id)))
        }
    }
    
    var shouldShowExtendedField: Bool {
        self.isHovering || self.isCurrentlyFocused
    }
    
    @State private var isHovering = false
    
    @State var isCurrentlyFocused: Bool = false
    
    
    
    
    var body: some View {
        
        // The small-width read-only field shown in an input-field of a canvas item
        // Note: layer inputs can be on the canvas, but ignore multiselect
        TapToEditReadOnlyView(inputString: self.inputString,
                              fieldWidth: fieldWidth,
                              isFocused: false,
                              isHovering: false,
                              isForLayerInspector: false,
                              hasChoices: choices.isDefined,
                              isForCanvas: true,
                              isForFlyout: false,
                              fieldHasHeterogenousValues: false,
                              isSelectedInspectorRow: false,
                              onTap: self.onFingerTap)
        .overlay {
            // TODO: show this even if we e.g. stop hovering but the field is focused
            if shouldShowExtendedField {
                TapToEditTextView(inputField: inputField,
                                  inputString: inputString,
                                  graph: graph,
                                  document: document,
                                  layerInput: nil,
                                  choices: choices,
                                  isLargeString: isLargeString,
                                  isForLayerInspector: false,
                                  isPackedLayerInputAlreadyOnCanvas: false,
                                  isFieldInMultifieldInput: isFieldInMultifieldInput,
                                  isForFlyout: false,
                                  isForSpacingField: isForSpacingField,
                                  isSelectedInspectorRow: false,
                                  hasHeterogenousValues: false,
                                  isFieldInMultifieldInspectorInputAndNotFlyout: false,
                                  
                                  // The 'tap-to-edit' view shown in this hover-overlay should always have the wide-extension
                                  fieldWidth: fieldWidth + hoveringAdjustment,
                                  isHovering: isHovering,
                                  isCurrentlyFocused: $isCurrentlyFocused)
                
                // TODO: proper picker-sensitive width
                .offset(x: hoveringAdjustment / 2)
            }
        }
        .onHover {
            self.isHovering = $0
        }
        
    }
}
