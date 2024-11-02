//
//  CommonEditingViewWrapper.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/30/24.
//

import SwiftUI
import StitchSchemaKit

struct CommonEditingViewWrapper: View {
    
    @Bindable var graph: GraphState
    @Bindable var fieldViewModel: InputFieldViewModel
    let layerInputObserver: LayerInputObserver?
    let fieldValue: FieldValue
    let fieldCoordinate: FieldCoordinate
    let isCanvasItemSelected: Bool
    let choices: [String]?
    let forPropertySidebar: Bool
    let propertyIsAlreadyOnGraph: Bool
    let isFieldInMultifieldInput: Bool
    let isForFlyout: Bool
    let isSelectedInspectorRow: Bool
    var isForSpacingField: Bool = false
    var isForLayerDimensionField: Bool = false
    var nodeKind: NodeKind
    
    @State private var isButtonPressed = false
    
    var fieldIndex: Int {
        self.fieldViewModel.fieldIndex
    }
    
    @MainActor
    var fieldHasHeterogenousValues: Bool {
        if let layerInputObserver = layerInputObserver {
            @Bindable var layerInputObserver = layerInputObserver
            return layerInputObserver.fieldHasHeterogenousValues(
                fieldIndex,
                isFieldInsideLayerInspector: forPropertySidebar)
        } else {
            return false
        }
    }
    
    var isFieldInMultifieldInspectorInputAndNotFlyout: Bool {
        isFieldInMultifieldInput && forPropertySidebar && !isForFlyout
    }
        
    // There MUST be an inspector-row for this
    // Can there be a better way to handle this?
    // Maybe don't care whether it's inside the inspector or not?
    @MainActor
    var isPaddingFieldInsideInspector: Bool {
        isFieldInMultifieldInspectorInputAndNotFlyout
        && (layerInputObserver?.activeValue.getPadding.isDefined ?? false)
    }
    
    @MainActor
    var fieldWidth: CGFloat {
        if isPaddingFieldInsideInspector {
            return PADDING_FIELD_WDITH
        } else if isForLayerDimensionField, !isFieldInMultifieldInspectorInputAndNotFlyout {
            // Only use longer width when not a multifeld on the inspector row itself
          return LAYER_DIMENSION_FIELD_WIDTH
        } else if isForSpacingField {
            return SPACING_FIELD_WIDTH
        } else if nodeKind.getPatch == .soulver {
            return SOULVER_NODE_INPUT_OR_OUTPUT_WIDTH
        } else if isFieldInMultifieldInspectorInputAndNotFlyout {
            // is this accurate for a spacing-field in the inspector?
            // ah but spacing is a dropdown
            return INSPECTOR_MULTIFIELD_INDIVIDUAL_FIELD_WIDTH
        } else {
            return NODE_INPUT_OR_OUTPUT_WIDTH
        }
    }
    
    var body: some View {
        let stringValue = fieldValue.stringValue
        
        if isFieldInMultifieldInput,
           forPropertySidebar,
           !isForFlyout,
           let layerInput = fieldViewModel.layerInput {
            
            CommonEditingViewReadOnly(
                inputField: fieldViewModel,
                inputString: stringValue,
                forPropertySidebar: forPropertySidebar,
                isHovering: false, // Always false
                choices: choices, // Always nil?
                fieldWidth: fieldWidth,
                fieldHasHeterogenousValues: fieldHasHeterogenousValues,
                isSelectedInspectorRow: isSelectedInspectorRow,
                isFieldInMultfieldInspectorInput: isFieldInMultifieldInspectorInputAndNotFlyout,
                onTap: {
                    if !isForFlyout {
                        dispatch(FlyoutToggled(
                            flyoutInput: layerInput,
                            flyoutNodeId: fieldCoordinate.rowId.nodeId,
                            fieldToFocus: .textInput(fieldCoordinate)))
                    }
                })
            
        } else {
            CommonEditingView(inputField: fieldViewModel,
                              layerInputObserver: layerInputObserver,
                              inputString: stringValue,
                              graph: graph,
                              fieldIndex: fieldCoordinate.fieldIndex,
                              isCanvasItemSelected: isCanvasItemSelected,
                              choices: choices,
                              isAdjustmentBarInUse: isButtonPressed,
                              forPropertySidebar: forPropertySidebar,
                              propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                              isFieldInMultifieldInput: isFieldInMultifieldInput,
                              isForFlyout: isForFlyout,
                              isForSpacingField: isForSpacingField,
                              isSelectedInspectorRow: isSelectedInspectorRow,
                              isFieldInMultifieldInspectorInputAndNotFlyout: isFieldInMultifieldInspectorInputAndNotFlyout,
                              fieldWidth: fieldWidth)
        }
    }
}
