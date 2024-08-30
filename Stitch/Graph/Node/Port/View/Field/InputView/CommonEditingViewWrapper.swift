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
    let inputLayerNodeRowData: InputLayerNodeRowData?
    let fieldValue: FieldValue
    let fieldCoordinate: FieldCoordinate
    let rowObserverCoordinate: NodeIOCoordinate
    let isCanvasItemSelected: Bool
    let hasIncomingEdge: Bool
    let choices: [String]?
    let adjustmentBarSessionId: AdjustmentBarSessionId
    let forPropertySidebar: Bool
    let propertyIsAlreadyOnGraph: Bool
    let isFieldInMultifieldInput: Bool
    let isForFlyout: Bool
    var isForSpacingField: Bool = false
    
    @State private var isButtonPressed = false
    
    var fieldIndex: Int {
        self.fieldViewModel.fieldIndex
    }
    
    @MainActor
    var fieldHasHeterogenousValues: Bool {
        if let inputLayerNodeRowData = inputLayerNodeRowData {
            @Bindable var inputLayerNodeRowData = inputLayerNodeRowData
            return inputLayerNodeRowData.fieldHasHeterogenousValues(
                fieldIndex,
//                isFieldInsideLayerInspector: isFieldInsideLayerInspector)
                // should be same as `forPropertySidebar`
                isFieldInsideLayerInspector: forPropertySidebar)
        } else {
            return false
        }
    }
    
    var isFieldInMultfieldInspectorInput: Bool {
        isFieldInMultifieldInput && forPropertySidebar && !isForFlyout
    }
    
    var isPaddingFieldInsideInspector: Bool {
        isFieldInMultfieldInspectorInput
        && (inputLayerNodeRowData?.inspectorRowViewModel.activeValue.getPadding.isDefined ?? false)
    }
    
    var fieldWidth: CGFloat {
        
        if isPaddingFieldInsideInspector {
            return PADDING_FIELD_WDITH
        } else if isFieldInMultfieldInspectorInput {
            // is this accurate for a spacing-field in the inspector?
            // ah but spacing is a dropdown
            return INSPECTOR_MULTIFIELD_INDIVIDUAL_FIELD_WIDTH
        } else if isForSpacingField {
            return SPACING_FIELD_WIDTH
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
                        
            let onTap: () -> Void = {
                if !isForFlyout {
                    dispatch(FlyoutToggled(flyoutInput: layerInput,
                                           flyoutNodeId: fieldCoordinate.rowId.nodeId))
                }
            }
            
            CommonEditingViewReadOnly(inputField: fieldViewModel,
                                      inputString: stringValue,
                                      forPropertySidebar: forPropertySidebar,
                                      isHovering: false, // Always false
                                      choices: choices,
                                      fieldWidth: fieldWidth,
                                      fieldHasHeterogenousValues: fieldHasHeterogenousValues,
                                      onTap: onTap)
            .border(.cyan)
            
//            .onTapGesture {
//                dispatch(FlyoutToggled(flyoutInput: layerInput,
//                                       flyoutNodeId: fieldViewModel.id.rowId.nodeId))
//            }
                
        } else {
           
                CommonEditingView(inputField: fieldViewModel,
                                  inputLayerNodeRowData: inputLayerNodeRowData,
                                  inputString: stringValue,
                                  graph: graph,
                                  fieldIndex: fieldCoordinate.fieldIndex,
                                  isCanvasItemSelected: isCanvasItemSelected,
                                  hasIncomingEdge: hasIncomingEdge,
                                  choices: choices,
                                  isAdjustmentBarInUse: isButtonPressed,
                                  forPropertySidebar: forPropertySidebar,
                                  propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                                  isFieldInMultifieldInput: isFieldInMultifieldInput,
                                  isForFlyout: isForFlyout,
                                  isForSpacingField: isForSpacingField,
                                  isFieldInMultfieldInspectorInput: isFieldInMultfieldInspectorInput,
                                  fieldWidth: fieldWidth)
        }
    }
}
