//
//  CommonEditingViewWrapper.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/30/24.
//

import SwiftUI
import StitchSchemaKit

struct CommonEditingView: View {
    
    @Bindable var document: StitchDocumentViewModel
    @Bindable var inputField: InputFieldViewModel
    
    let layerInput: LayerInputPort?
        
    let choices: [String]?
    
    let isLargeString: Bool
    
    let isForLayerInspector: Bool
    let isPackedLayerInputAlreadyOnCanvas: Bool
    let hasHeterogenousValues: Bool
    
    let isFieldInMultifieldInput: Bool
    
    let isForFlyout: Bool
    
    let isSelectedInspectorRow: Bool

    var isForSpacingField: Bool = false
    var isForLayerDimensionField: Bool = false
    
    var nodeKind: NodeKind
       
    var isFieldInMultifieldInspectorInputAndNotFlyout: Bool {
        isFieldInMultifieldInput && isForLayerInspector && !isForFlyout
    }
        
    @MainActor
    var fieldWidth: CGFloat {
        if isForLayerDimensionField, !isFieldInMultifieldInspectorInputAndNotFlyout {
            // Only use longer width when not a multifeld on the inspector row itself
          return LAYER_DIMENSION_FIELD_WIDTH
        } else if isForSpacingField {
            return SPACING_FIELD_WIDTH
        } else if nodeKind.getPatch == .soulver {
            return SOULVER_NODE_INPUT_OR_OUTPUT_WIDTH
        } else if isFieldInMultifieldInspectorInputAndNotFlyout {
            // e.g. Position or Size inputs in the layer inspector (but not flyout)
            return INSPECTOR_MULTIFIELD_INDIVIDUAL_FIELD_WIDTH
        } else {
            // default case
            return NODE_INPUT_OR_OUTPUT_WIDTH
        }
    }
    
    var isCanvasField: Bool {
        inputField.id.rowId.graphItemType.getCanvasItemId.isDefined
    }
    
    var body: some View {
        
        // If for a canvas field, we show `TapToEditTextView` in a hovered view
        if isCanvasField {
          CanvasCommonEditingView(document: document,
                                  inputField: inputField,
                                  choices: choices,
                                  isLargeString: isLargeString,
                                  fieldWidth: fieldWidth)
        }
        
        // Otherwise (flyout or inspector) we show the `TapToEditTextView` *without* hover
        else {
            TapToEditTextView(
                document: document,
                inputField: inputField,
                fieldWidth: fieldWidth,
                
                // Picker
                choices: choices,
                hasPicker: choices.isDefined && !isFieldInMultifieldInspectorInputAndNotFlyout,
                
                // Base64
                isLargeString: isLargeString,
                
                // Inspector/flyout
                isForLayerInspector: isForLayerInspector,
                isPackedLayerInputAlreadyOnCanvas: isPackedLayerInputAlreadyOnCanvas,
                isSelectedInspectorRow: isSelectedInspectorRow,
                hasHeterogenousValues: hasHeterogenousValues,
                isFieldInMultifieldInspectorInputAndNotFlyout: isFieldInMultifieldInspectorInputAndNotFlyout,
                                
                // Only relevant for canvas input fields
                isHovering: false,
                isCurrentlyFocused: .constant(false),
                
                // i.e. Inspector or flyout input/field tapped
                onReadOnlyTap: {
                    if isFieldInMultifieldInspectorInputAndNotFlyout,
                       let layerInput = layerInput {
                        dispatch(FlyoutToggled(flyoutInput: layerInput,
                                               flyoutNodeId: inputField.id.rowId.nodeId,
                                               fieldToFocus: .textInput(inputField.id)))
                    } else {
                        dispatch(ReduxFieldFocused(focusedField: .textInput(inputField.id)))
                    }
                })
        } // else
    }
}
