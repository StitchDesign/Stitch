//
//  FieldValueNumberView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/30/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct  FieldValueNumberView: View {

    @Bindable var graph: GraphState
    let fieldValue: FieldValue
    let fieldValueNumberType: FieldValueNumberType
    let coordinate: NodeIOCoordinate
    let nodeIO: NodeIO
    let fieldCoordinate: FieldCoordinate
    let outputAlignment: Alignment
    let isNodeSelected: Bool
    let hasIncomingEdge: Bool
    let adjustmentBarSessionId: AdjustmentBarSessionId
    let forPropertySidebar: Bool

    @State private var isButtonPressed = false

    var body: some View {
        let stringValue = fieldValue.stringValue

        Group {
            switch nodeIO {
            case .input:
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

                    CommonEditingView(inputString: stringValue,
                                      id: coordinate,
                                      graph: graph,
                                      fieldIndex: fieldCoordinate.fieldIndex,
                                      isNodeSelected: isNodeSelected,
                                      hasIncomingEdge: hasIncomingEdge,
                                      isAdjustmentBarInUse: isButtonPressed,
                                      forPropertySidebar: forPropertySidebar)
                }
            case .output:
                ReadOnlyValueEntry(value: stringValue,
                                   alignment: outputAlignment,
                                   fontColor: STITCH_FONT_GRAY_COLOR)
            }
        }
    }
}
