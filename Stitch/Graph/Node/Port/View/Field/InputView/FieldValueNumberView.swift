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
    let isSelectedInspectorRow: Bool
    var isForSpacingField: Bool = false
    var nodeKind: NodeKind
    
    @State private var isButtonPressed = false
    
    var fieldIndex: Int {
        self.fieldViewModel.fieldIndex
    }
    
    // Bad: do not want this running constantly when we're not inside a
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
    
    var isFieldInMultifieldInputInInspector: Bool {
        isFieldInMultifieldInput && forPropertySidebar && !isForFlyout
    }
    
    var body: some View {
        
        HStack {
            
            // Do not show number adjustment bar if field is part of a multifield input inside the layer inspector
            if !isFieldInMultifieldInputInInspector {
                
                // Default to zero if "auto" currently selected
                // Limit renders by not passing in number value unless button pressed
                NumberValueButtonView(graph: graph,
                                      value: isButtonPressed ? fieldValue.numberValue : .zero,
                                      fieldCoordinate: fieldCoordinate,
                                      rowObserverCoordinate: rowObserverCoordinate,
                                      fieldValueNumberType: fieldValueNumberType,
                                      adjustmentBarSessionId: adjustmentBarSessionId,
                                      isFieldInsideLayerInspector: fieldViewModel.isFieldInsideLayerInspector, 
                                      isSelectedInspectorRow: isSelectedInspectorRow,
                                      isPressed: $isButtonPressed)
            }
            
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
                                     isForFlyout: isForFlyout, 
                                     isSelectedInspectorRow: isSelectedInspectorRow, 
                                     nodeKind: nodeKind)
        }
    }
}
