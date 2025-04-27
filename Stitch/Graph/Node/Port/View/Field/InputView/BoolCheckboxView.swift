//
//  BoolCheckboxView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/11/22.
//

import SwiftUI
import StitchSchemaKit

// TODO: what "multi" value should we show for a checkbox?
struct BoolCheckboxView: View {
    
    @Environment(\.appTheme) var theme
    
    let rowObserverId: InputCoordinate? // nil = used in output
    let value: Bool
    let isFieldInsideLayerInspector: Bool
    let isSelectedInspectorRow: Bool
    let isMultiselectInspectorInputWithHeterogenousValues: Bool
    
    @MainActor
    var iconName: String {
        if isMultiselectInspectorInputWithHeterogenousValues {
            return "minus.square"
        } else if value {
            return "checkmark.square"
        } else {
            return "square"
        }
    }
    
    var themeColor: Color {
        theme.fontColor
    }
    
    var body: some View {

        // TODO: Why does `.animation(value: Bool)` not work for Image changes?
        Image(systemName: iconName)
            .foregroundColor(isSelectedInspectorRow ? themeColor : .primary)
        
        // TODO: how to "fill" the background of the checkbox symbol?
//            .background {
//                if isFieldInsideLayerInspector && isSelectedInspectorRow {
//                    return themeColor. //.INSPECTOR_FIELD_BACKGROUND_COLOR.overlay(themeColor.opacity(0.5))
//                } else if isFieldInsideLayerInspector {
//                    return .INSPECTOR_FIELD_BACKGROUND_COLOR
//                } else {
//                    return .clear
//                }
//            }
            .onTapGesture {
                if let rowObserverId = rowObserverId {
                    let toggled = toggleBool(value)
                    dispatch(PickerOptionSelected(id: rowObserverId,
                                                  choice: .bool(toggled),
                                                  isFieldInsideLayerInspector: isFieldInsideLayerInspector))
                }
            }
    }
}

//struct BoolCheckboxView_Previews: PreviewProvider {
//    static var previews: some View {
//        BoolCheckboxView(
//            id: InputCoordinate.fakeInputCoordinate,
//            value: true)
//            .scaleEffect(5)
//    }
//}
