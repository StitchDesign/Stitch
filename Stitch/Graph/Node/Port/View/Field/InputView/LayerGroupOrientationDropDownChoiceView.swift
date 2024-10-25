//
//  LayerGroupOrientationDropDownChoiceView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 10/17/24.
//

import SwiftUI
import StitchSchemaKit

extension StitchOrientation {
    var canUseHug: Bool {
        switch self {
        case .horizontal, .vertical, .grid:
            return true
        case .none:
            return false
        }
    }
    
    var sfSymbol: String {
        switch self {
        case .none:
            return "rectangle.stack"
        case .horizontal:
            return "arrow.right"
        case .vertical:
            return "arrow.down"
        case .grid:
            return "return"
        }
    }
}

// TODO: how to handle multiple-layers-selected? ... Why does using "String" type for Picker cause view to not appear?
struct LayerGroupOrientationDropDownChoiceView: View {
    @State private var currentChoice: StitchOrientation = .none
//    @State private var currentChoice: String = ""
    
    let id: InputCoordinate
    let value: StitchOrientation
    let layerInputObserver: LayerInputObserver?
    let isFieldInsideLayerInspector: Bool
    
    var choices: [StitchOrientation] {
        StitchOrientation.choices.compactMap(\.getOrientation)
    }
//    var choices: [String] {
//        StitchOrientation.choices.compactMap(\.getOrientation?.display)
//    }
    
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
        Picker("Here", selection: $currentChoice) {
            ForEach(choices, id: \.self) { choice in
//                if let choice = StitchOrientation(rawValue: choice) {
                    Image(systemName: choice.sfSymbol).tag(choice)
//                }
            }
        }
        .pickerStyle(.segmented)
        .scaledToFit()
        .frame(width: 148, height: NODE_ROW_HEIGHT * 2, alignment: .trailing)
        // .frame(width: 148, height: NODE_ROW_HEIGHT * 1.5, alignment: .trailing)
        .onChange(of: self.currentChoice) { oldValue, newValue in
//            if let newChoice = StitchOrientation(rawValue: newValue) {
                dispatch(PickerOptionSelected(input: self.id,
//                                              choice: .orientation(newChoice),
                                              choice: .orientation(newValue),
                                              isFieldInsideLayerInspector: isFieldInsideLayerInspector))
//            }
            
        }
        .onAppear {
//            if !self.hasHeterogenousValues {
//                self.currentChoice = value.display
//            }
            self.currentChoice = value
        }
//        .onChange(of: self.hasHeterogenousValues) { oldValue, newValue in
//            if newValue {
//                self.currentChoice = "" // To deselect all options
//            }
//        }
    }
}
