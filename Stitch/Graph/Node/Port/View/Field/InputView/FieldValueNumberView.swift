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

    var body: some View {
        if isFieldInMultifieldInput, 
            forPropertySidebar,
            !isForFlyout,
           let layerInput = fieldViewModel.layerInput {
            
//            commonEditView
            
            let stringValue = fieldValue.stringValue
            StitchTextView(string: stringValue)
                .onTapGesture {
                    dispatch(FlyoutToggled(flyoutInput: layerInput,
                                           flyoutNodeId: fieldViewModel.id.rowId.nodeId))
                }
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
                
                commonEditView
            }
        }
    }
    
    @ViewBuilder
    var commonEditView: CommonEditingView {
        let stringValue = fieldValue.stringValue
        
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
                          isForSpacingField: isForSpacingField)
    }
}
