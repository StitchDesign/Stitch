//
//  SpecialPickerFieldValueView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/21/25.
//

import SwiftUI

struct SpecialPickerFieldValueView: View {
    @State var currentChoice: PortValue
    
    let id: InputCoordinate
    let value: PortValue
    let choices: PortValues
    let layerInputObserver: LayerInputObserver?
    let isFieldInsideLayerInspector: Bool
    
    @MainActor
    var hasHeterogenousValues: Bool {
        if let layerInputObserver = layerInputObserver {
            @Bindable var layerInputObserver = layerInputObserver
            return layerInputObserver.fieldHasHeterogenousValues(
                0,
                isFieldInsideLayerInspector: isFieldInsideLayerInspector)
        } else {
            return false
        }
    }
    
    var body: some View {
        Picker("", selection: $currentChoice) {
            ForEach(choices, id: \.self) { choice in
                Image(systemName: choice.sfSymbol).tag(choice)
            }
        }
        .pickerStyle(.segmented)
        .scaledToFit()
        .frame(width: 148, height: NODE_ROW_HEIGHT * 2, alignment: .trailing)
        .onChange(of: self.currentChoice) { oldValue, newValue in
                dispatch(PickerOptionSelected(
                    input: self.id,
                    choice: newValue,
                    isFieldInsideLayerInspector: isFieldInsideLayerInspector))
        }
        .onAppear {
            self.currentChoice = value
        }
    }
}
