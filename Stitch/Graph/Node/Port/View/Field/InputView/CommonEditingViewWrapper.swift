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
    @Bindable var graphUI: GraphUIState
    @Bindable var fieldViewModel: InputFieldViewModel
    @Bindable var rowObserver: InputNodeRowObserver
    let rowViewModel: InputNodeRowViewModel
    let fieldValue: FieldValue
    let fieldCoordinate: FieldCoordinate
    let isCanvasItemSelected: Bool
    let choices: [String]?
    let isForLayerInspector: Bool
    let isPackedLayerInputAlreadyOnCanvas: Bool
    let hasHeterogenousValues: Bool
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
    
    var body: some View {
        let stringValue = fieldValue.stringValue
        CommonEditingView(inputField: fieldViewModel,
                          inputString: stringValue,
                          graph: graph,
                          graphUI: graphUI,
                          rowObserver: rowObserver,
                          rowViewModel: rowViewModel,
                          fieldIndex: fieldCoordinate.fieldIndex,
                          isCanvasItemSelected: isCanvasItemSelected,
                          choices: choices,
                          isAdjustmentBarInUse: isButtonPressed,
                          isForLayerInspector: isForLayerInspector,
                          isPackedLayerInputAlreadyOnCanvas: isPackedLayerInputAlreadyOnCanvas,
                          isFieldInMultifieldInput: isFieldInMultifieldInput,
                          isForFlyout: isForFlyout,
                          isForSpacingField: isForSpacingField,
                          isSelectedInspectorRow: isSelectedInspectorRow,
                          hasHeterogenousValues: hasHeterogenousValues,
                          isFieldInMultifieldInspectorInputAndNotFlyout: isFieldInMultifieldInspectorInputAndNotFlyout,
                          fieldWidth: fieldWidth)
    }
}
