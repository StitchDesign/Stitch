//
//  CommonEditingView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/25/22.
//

import SwiftUI
import StitchSchemaKit

struct CommonEditingView: View {
    
    
    // MARK: PASSED-IN VIEW PARAMETERS
    
    @Bindable var inputField: InputFieldViewModel
    
    let inputString: String
    
    @Bindable var graph: GraphState
    @Bindable var document: StitchDocumentViewModel
    
    let layerInput: LayerInputPort?
    
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
    
    
    var isCanvasField: Bool {
        inputField.id.rowId.graphItemType.getCanvasItemId.isDefined
    }
    
    var body: some View {
        
        // If for a canvas field, we show `TapToEditTextView` in the hovered view
        if isCanvasField {
          CanvasCommonEditingView(inputField: inputField,
                                  inputString: inputString,
                                  graph: graph,
                                  document: document,
                                  isFieldInMultifieldInput: isFieldInMultifieldInput,
                                  isForSpacingField: isForSpacingField,
                                  isFieldInMultifieldInspectorInputAndNotFlyout: isFieldInMultifieldInspectorInputAndNotFlyout,
                                  fieldWidth: fieldWidth)
            
        }
        
        // Otherwise (e.g. flyout or inspector) we show the "tap to edit" view *without* hover
        else {
            // Starts out read-only; becomes editable when tapped; becomes read-only again when submitted or otherwise defocused
            TapToEditTextView(
                inputField: inputField,
                inputString: inputString,
                graph: graph,
                document: document,
                layerInput: layerInput,
                choices: choices,
                isLargeString: isLargeString,
                isForLayerInspector: isForLayerInspector,
                isPackedLayerInputAlreadyOnCanvas: isPackedLayerInputAlreadyOnCanvas,
                isFieldInMultifieldInput: isFieldInMultifieldInput,
                isForFlyout: isForFlyout,
                isForSpacingField: isForSpacingField,
                isSelectedInspectorRow: isSelectedInspectorRow,
                hasHeterogenousValues: hasHeterogenousValues,
                isFieldInMultifieldInspectorInputAndNotFlyout: isFieldInMultifieldInspectorInputAndNotFlyout,
                fieldWidth: fieldWidth,
                
                // Only applicable
                isCurrentlyFocused: .constant(false))
        }
        
    }
}

struct CanvasCommonEditingView: View {
    
    @Bindable var inputField: InputFieldViewModel
    
    let inputString: String
    
    @Bindable var graph: GraphState
    @Bindable var document: StitchDocumentViewModel
        
    // Only for field-types that use a "TextField + Dropdown" view,
    // e.g. `LayerDimension`
    var choices: [String]?  = nil // ["fill", "auto"]
    
    var isLargeString: Bool = false
        
    // inspector only?
    let isFieldInMultifieldInput: Bool
    
    let isForSpacingField: Bool
    
    // also inspector-only ?
    // TODO: APRIL 29
    let isFieldInMultifieldInspectorInputAndNotFlyout: Bool
    
    let fieldWidth: CGFloat
    
        
    static let HOVER_EXTRA_LENGTH: CGFloat = 52
    
    var hoveringAdjustment: CGFloat {
        isShowingExtendedField ? Self.HOVER_EXTRA_LENGTH : 0
    }
    
    // For canvas fields on iPad where hover may not be available (e.g. no trackpad),
    // tap should focuses the field.
    func onFingerTap() {
        log("finger tap")
        if !self.isHovering {
            dispatch(ReduxFieldFocused(focusedField: .textInput(self.inputField.id)))
        }
    }
    
    var isShowingExtendedField: Bool {
        self.isHovering || self.isCurrentlyFocused
    }
    
    @State private var isHovering = false
    
    @State var isCurrentlyFocused: Bool = false
    
    var body: some View {
        
        // The small-width read-only field shown in an input-field of a canvas item
        // Note: layer inputs can be on the canvas, but ignore multiselect
        CommonEditingViewReadOnly(inputString: self.inputString,
                                  fieldHasHeterogenousValues: false,
                                  isSelectedInspectorRow: false,
                                  onTap: self.onFingerTap)
                
        .contentShape(Rectangle())
        
            .frame(width: fieldWidth, // TODO: APRIL 29:  handle picker etc.
                   alignment: .leading)
        
            .padding([.leading, .top, .bottom], 2)
        
            .contentShape(Rectangle())
        
            .overlay {
                // TODO: show this even if we e.g. stop hovering but the field is focused
                if isHovering || isCurrentlyFocused {
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
                                      fieldWidth: fieldWidth,
                                      isCurrentlyFocused: $isCurrentlyFocused)
//                    .onTapGesture(perform: {
//                        log("canvas hovering TAPPED")
//                    })
                
                    // TODO: proper picker-sensitive width
                        .frame(width: fieldWidth + hoveringAdjustment,
                               alignment: .leading)
                    
                    // order of .frame vs .padding ?
                    // May need to pass down `fieldWidth + hovering adjustments` to the TapToEditTextView
//                    .frame(width: fieldWidth,
//                           alignment: .leading)
                    
                    .padding([.leading, .top, .bottom], 2)
                    
                        .modifier(InputFieldBackgroundColorView(
                            isHovering: isHovering,
                            isFocused: isCurrentlyFocused))

                        .offset(x: hoveringAdjustment / 2)
                        .contentShape(Rectangle())
                    
                }
            }
            .onHover {
                self.isHovering = $0
            }
                                  
    }
}
