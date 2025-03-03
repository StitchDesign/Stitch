//
//  LayerGroupAlignmentChoicesView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/21/25.
//

import SwiftUI

// TODO: clean this up; at least combine the two views

enum HorizontalAlignmentChoices: Equatable, Hashable, CaseIterable {
    case left, center, right
    
    var sfSymbol: String {
        switch self {
        case .left:
            return "align.horizontal.left"
        case .center:
            return "align.horizontal.center"
        case .right:
            return "align.horizontal.right"
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


struct LayerGroupHorizontalAlignmentPickerFieldValueView: View {
    @State var currentChoice: HorizontalAlignmentChoices = .center
    
    let rowObserver: InputNodeRowObserver
    let graph: GraphState
    let value: Anchoring
    let layerInputObserver: LayerInputObserver?
    let isFieldInsideLayerInspector: Bool
    let hasHeterogenousValues: Bool
    
    var body: some View {
        Picker("", selection: $currentChoice) {
            ForEach(HorizontalAlignmentChoices.allCases, id: \.self) { choice in
                Image(systemName: choice.sfSymbol).tag(choice)
            }
        }
        .pickerStyle(.segmented)
        .scaledToFit()
        .frame(width: 148, height: NODE_ROW_HEIGHT * 2, alignment: .trailing)
        .onChange(of: self.currentChoice) { oldValue, newValue in
            graph.pickerOptionSelected(
                rowObserver: rowObserver,
                choice: .anchoring(newValue.asAnchoring),
                isFieldInsideLayerInspector: isFieldInsideLayerInspector)
        }
        .onAppear {
            self.currentChoice = .fromAnchoring(value)
        }
    }
}

struct LayerGroupVerticalAlignmentPickerFieldValueView: View {
    @State var currentChoice: VerticalAlignmentChoices = .center
    
    let rowObserver: InputNodeRowObserver
    let graph: GraphState
    let value: Anchoring
    let layerInputObserver: LayerInputObserver?
    let isFieldInsideLayerInspector: Bool
    let hasHeterogenousValues: Bool
    
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
            graph.pickerOptionSelected(
                rowObserver: rowObserver,
                choice: .anchoring(newValue.asAnchoring),
                isFieldInsideLayerInspector: isFieldInsideLayerInspector)
        }
        .onAppear {
            self.currentChoice = .fromAnchoring(value)
        }
    }
}
