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
    let id: InputCoordinate? // nil = used in output
    let inputLayerNodeRowData: InputLayerNodeRowData?
    let value: Bool
    let isFieldInsideLayerInspector: Bool
    let isSelectedInspectorRow: Bool

    @MainActor
    var isMultiselectInspectorInputWithHeterogenousValues: Bool {
        if let inputLayerNodeRowData = inputLayerNodeRowData {
            @Bindable var inputLayerNodeRowData = inputLayerNodeRowData
            return inputLayerNodeRowData.fieldHasHeterogenousValues(
                0,
                isFieldInsideLayerInspector: isFieldInsideLayerInspector)
        } else {
            return false
        }
    }
    
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
    
    var body: some View {

        // TODO: Why does `.animation(value: Bool)` not work for Image changes?
        Image(systemName: iconName)
            .modifier(SelectedInInspectorColorOverlay(isSelectedInspectorRow: isSelectedInspectorRow))
            .onTapGesture {
                if let id = id {
                    log("BoolCheckboxView: id: \(id)")
                    let toggled = toggleBool(value)
                    dispatch(PickerOptionSelected(
                                input: id,
                                choice: .bool(toggled),
                                isFieldInsideLayerInspector: isFieldInsideLayerInspector))
                }
            }
    }
}

struct SelectedInInspectorColorOverlay: ViewModifier {
    let isSelectedInspectorRow: Bool
    
    @Environment(\.appTheme) var theme
    
    func body(content: Content) -> some View {
        if isSelectedInspectorRow {
            content.overlay {
                theme.fontColor.opacity(0.2)
            }
        } else {
            content
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
