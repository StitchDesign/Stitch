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
    let value: Bool
    let isFieldInsideLayerInspector: Bool

    var body: some View {

        // TODO: Why does `.animation(value: Bool)` not work for Image changes?
        Image(systemName: value ? "checkmark.square" : "square")
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

//struct BoolCheckboxView_Previews: PreviewProvider {
//    static var previews: some View {
//        BoolCheckboxView(
//            id: InputCoordinate.fakeInputCoordinate,
//            value: true)
//            .scaleEffect(5)
//    }
//}
