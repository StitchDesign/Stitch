//
//  SpecialPickerFieldValueView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/21/25.
//

import SwiftUI

extension LayerTextAlignment {
    var sfSymbol: String {
        switch self {
        case .left:
            return "text.alignleft"
        case .center:
            return "text.aligncenter"
        case .right:
            return "text.alignright"
        case .justify:
            return "text.justify"
        }
    }
}

extension LayerTextVerticalAlignment {
    var sfSymbol: String {
        switch self {
        case .top:
            return "arrow.up.to.line.compact"
        case .center:
            return "arrow.down.and.line.horizontal.and.arrow.up"
        case .bottom:
            return "arrow.down.to.line.compact"
        }
    }
}

extension LayerTextDecoration {
    var sfSymbol: String {
        switch self {
        case .none:
            return "textformat"
        case .underline:
            return "underline"
        case .strikethrough:
            return "strikethrough"
        }
    }
}

extension PortValue {
    // Only intended for special pickers
    var sfSymbol: String {
        switch self {
        case .textAlignment(let x):
            return x.sfSymbol
        case .textVerticalAlignment(let x):
            return x.sfSymbol
        case .textDecoration(let x):
            return x.sfSymbol
        default:
            return ""
        }
    }
}


struct SpecialPickerFieldValueView: View {
    @State var currentChoice: PortValue
    
    let rowObserver: InputNodeRowObserver
    let graph: GraphState
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
            graph.pickerOptionSelected(
                rowObserver: rowObserver,
                choice: newValue,
                isFieldInsideLayerInspector: isFieldInsideLayerInspector)
        }
        .onAppear {
            self.currentChoice = value
        }
    }
}
