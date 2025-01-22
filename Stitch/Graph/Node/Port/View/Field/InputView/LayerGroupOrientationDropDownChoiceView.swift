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


// this UI is quite a bit different, because you are receiving a full PortValue.anchoring enum,
// but want to show something more specific
extension Anchoring {
    func sfSymbolForLayerGroupOrientation(_ orientation: StitchOrientation) -> String {
        switch orientation {
        case .grid, .none:
            fatalErrorIfDebug()
            return "" // should not happen
        case .horizontal:
            return "align.horizontal.left"
        case .vertical:
            return "align.vertical.top"
        }
    }
}

enum HorizontalAlignmentChoices: Equatable, Hashable, CaseIterable {
    case left, center, right
    
    var sfSymbol: String {
        switch self {
        case .left:
            return "align.vertical.left"
        case .center:
            return "align.vertical.center"
        case .right:
            return "align.vertical.right"
        }
    }
    
    var asAnchoring: Anchoring {
        switch self {
        case .left:
            return .centerLeft
        case .center:
            return .centerCenter
        case .right:
            return .centerRight
        }
    }
    
    static func fromAnchoring(_ anchoring: Anchoring) -> Self {
        switch anchoring {
        case .topLeft:
            return .left
        case .topCenter:
            return .center
        case .topRight:
            return .right
        case .centerLeft:
            return .left
        case .centerCenter:
            return .center
        case .centerRight:
            return .right
        case .bottomLeft:
            return .left
        case .bottomCenter:
            return .center
        case .bottomRight:
            return .right
        
        /*
         TODO: turn various numbers into proper alignments? e.g.
         x < 0.3 is .leading alignment,
         x > 0.7 is .trailing;
         everything else is .center
         */
        default:
            return .center // some default
        }
    }
}

enum VerticalAlignmentChoices: Equatable, Hashable, CaseIterable {
    case top, center, bottom
    
    var sfSymbol: String {
        switch self {
        case .top:
            return "align.vertical.top"
        case .center:
            return "align.vertical.center"
        case .bottom:
            return "align.vertical.bottom"
        }
    }
    
    var asAnchoring: Anchoring {
        switch self {
        case .top:
            return .topCenter
        case .center:
            return .centerCenter
        case .bottom:
            return .bottomCenter
        }
    }
    
    static func fromAnchoring(_ anchoring: Anchoring) -> Self {
        switch anchoring {
        case .topLeft:
            return .top
        case .topCenter:
            return .top
        case .topRight:
            return .top
        case .centerLeft:
            return .center
        case .centerCenter:
            return .center
        case .centerRight:
            return .center
        case .bottomLeft:
            return .bottom
        case .bottomCenter:
            return .bottom
        case .bottomRight:
            return .bottom
        
        /*
         TODO: turn various numbers into proper alignments? e.g.
         y < 0.3 is .top alignment,
         y > 0.7 is .bottom;
         everything else is .center
         */
        default:
            return .center
        }
    }
}


struct LayerGroupVerticalAlignmentPickerFieldValueView: View {
    @State var currentChoice: VerticalAlignmentChoices = .center
    
    let id: InputCoordinate
    let value: Anchoring
    
    // VStack = show ...
    // HStack = show ...
    // None or Grid = this field will actually be blocked
    
//    let layerGroupOrientation: StitchOrientation
    
    var isVStack: Bool {
        true
    }
    
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
            ForEach(VerticalAlignmentChoices.allCases, id: \.self) { choice in
                Image(systemName: choice.sfSymbol).tag(choice)
            }
        }
        .pickerStyle(.segmented)
        .scaledToFit()
        .frame(width: 148, height: NODE_ROW_HEIGHT * 2, alignment: .trailing)
        .onChange(of: self.currentChoice) { oldValue, newValue in
                dispatch(PickerOptionSelected(
                    input: self.id,
                    choice: .anchoring(newValue.asAnchoring),
                    isFieldInsideLayerInspector: isFieldInsideLayerInspector))
        }
        .onAppear {
            self.currentChoice = .fromAnchoring(value)
        }
    }
}

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
