//
//  FieldValueNumberView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/30/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct FieldValueNumberView: View {
    
    @Bindable var graph: GraphState
    @Bindable var fieldViewModel: InputFieldViewModel
    let inputLayerNodeRowData: InputLayerNodeRowData?
    let fieldValue: FieldValue
    let fieldValueNumberType: FieldValueNumberType
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
    
    var fieldWidth: CGFloat {
        if isFieldInMultfieldInspectorInput {
            return INSPECTOR_MULTIFIELD_INDIVIDUAL_FIELD_WIDTH
        }  else if isForSpacingField {
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
            
            CommonEditingViewReadOnly(inputField: fieldViewModel,
                                      inputString: stringValue,
                                      forPropertySidebar: forPropertySidebar,
                                      isHovering: false, // Always false
                                      choices: choices,
                                      fieldWidth: fieldWidth,
                                      fieldHasHeterogenousValues: fieldHasHeterogenousValues,
                                      onTap: {
                if !isForFlyout {
                    dispatch(FlyoutToggled(flyoutInput: layerInput,
                                           flyoutNodeId: fieldCoordinate.rowId.nodeId))
                }
            })
            .border(.cyan)
            
        } else {
            HStack {
                // Default to zero if "auto" currently selected
                // Limit renders by not passing in number value unless button pressed
                NumberValueButtonView(graph: graph,
                                      value: isButtonPressed ? fieldValue.numberValue : .zero,
                                      fieldCoordinate: fieldCoordinate,
                                      rowObserverCoordinate: rowObserverCoordinate,
                                      fieldValueNumberType: fieldValueNumberType,
                                      adjustmentBarSessionId: adjustmentBarSessionId,
                                      isFieldInsideLayerInspector: fieldViewModel.isFieldInsideLayerInspector,
                                      isPressed: $isButtonPressed)
                
                CommonEditingViewWrapper(graph: graph,
                                         fieldViewModel: fieldViewModel,
                                         inputLayerNodeRowData: inputLayerNodeRowData,
                                         fieldValue: fieldValue,
                                         fieldCoordinate: fieldCoordinate,
                                         rowObserverCoordinate: rowObserverCoordinate,
                                         isCanvasItemSelected: isCanvasItemSelected,
                                         hasIncomingEdge: hasIncomingEdge,
                                         choices: nil,
                                         adjustmentBarSessionId: adjustmentBarSessionId,
                                         forPropertySidebar: forPropertySidebar,
                                         propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph,
                                         isFieldInMultifieldInput: isFieldInMultifieldInput,
                                         isForFlyout: isForFlyout)
            }
        }
    }
}
