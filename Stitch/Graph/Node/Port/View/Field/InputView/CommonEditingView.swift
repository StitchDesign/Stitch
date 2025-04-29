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
                                  choices: choices,
                                  isLargeString: isLargeString,
                                  isForFlyout: isForFlyout,
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
                isHovering: false,
                isCurrentlyFocused: .constant(false))
        }
        
    }
}

