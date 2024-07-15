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
    let fieldValue: FieldValue
    let fieldValueNumberType: FieldValueNumberType
    let fieldCoordinate: FieldCoordinate
    let isCanvasItemSelected: Bool
    let hasIncomingEdge: Bool
    let adjustmentBarSessionId: AdjustmentBarSessionId
    let forPropertySidebar: Bool
    let propertyIsAlreadyOnGraph: Bool

    @State private var isButtonPressed = false

    var body: some View {
        let stringValue = fieldValue.stringValue
        
        HStack {
            // Default to zero if "auto" currently selected
            // Limit renders by not passing in number value unless button pressed
            NumberValueButtonView(
                graph: graph,
                value: isButtonPressed ? fieldValue.numberValue : .zero,
                fieldCoordinate: fieldCoordinate,
                fieldValueNumberType: fieldValueNumberType,
                adjustmentBarSessionId: adjustmentBarSessionId,
                isPressed: $isButtonPressed)
            
            CommonEditingView(inputField: fieldViewModel,
                              inputString: stringValue,
                              graph: graph,
                              fieldIndex: fieldCoordinate.fieldIndex,
                              isCanvasItemSelected: isCanvasItemSelected,
                              hasIncomingEdge: hasIncomingEdge,
                              isAdjustmentBarInUse: isButtonPressed,
                              forPropertySidebar: forPropertySidebar,
                              propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph)
        }
    }
}
