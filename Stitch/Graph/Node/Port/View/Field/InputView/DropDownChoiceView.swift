//
//  DropDownChoiceView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/3/22.
//

import SwiftUI
import StitchSchemaKit

// Picker that chooses between MacOS vs iOS dropdowns
struct DropDownChoiceView: View {

    @Environment(\.appTheme) var theme
    
    let rowObserver: InputNodeRowObserver
    
    let layerInputObserver: LayerInputObserver?
    
    @Bindable var graph: GraphState
    
    let choiceDisplay: String
    let choices: PortValues
    let isFieldInsideLayerInspector: Bool
    let isSelectedInspectorRow: Bool
    let hasHeterogenousValues: Bool
    let activeIndex: ActiveIndex

    @MainActor
    var finalChoiceDisplay: String {
        self.hasHeterogenousValues ? .HETEROGENOUS_VALUES : self.choiceDisplay
    }
    
    var body: some View {
        Menu {
            StitchPickerView(input: rowObserver,
                             graph: graph,
                             choices: choices,
                             choiceDisplay: finalChoiceDisplay,
                             isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                             activeIndex: activeIndex)
        } label: {
            StitchTextView(string: finalChoiceDisplay,
                           fontColor: isSelectedInspectorRow ? theme.fontColor : STITCH_FONT_GRAY_COLOR)
        }
        #if targetEnvironment(macCatalyst)
        .menuIndicator(.hidden) // hide caret indicator
        .menuStyle(.button)

        // fixes Catalyst accent-color issue
        .buttonStyle(.plain)
        .foregroundColor(STITCH_TITLE_FONT_COLOR)
        .pickerStyle(.inline) // avoids unnecessary middle label
        #endif
    }
}

// TODO: use for more dropdown menus, including layers and wireless?
// see https://github.com/vpl-codesign/stitch/issues/5294
struct StitchPickerView: View {

    let input: InputNodeRowObserver
    let graph: GraphState
    let choices: PortValues
    let choiceDisplay: String // current choice
    let isFieldInsideLayerInspector: Bool
    let activeIndex: ActiveIndex

    var pickerLabel: String {
        // slightly different Picker label logic for Catalyst vs iPad
        #if targetEnvironment(macCatalyst)
        ""
        #else
        choiceDisplay
        #endif
    }

    var pickerChoices: [String] {
        choices.map(\.display)
    }
    
    @MainActor func onSet(selection: String) {
        
        // TODO: make these logic cleaner? pass PortValue instead of String to Picker ?
        let _selection = choices.first(where: { $0.display == selection })
        
        if let _selection = _selection {
            graph.pickerOptionSelected(rowObserver: input,
                                       choice: _selection,
                                       activeIndex: activeIndex,
                                       isFieldInsideLayerInspector: isFieldInsideLayerInspector)
        } else {
            log("StitchPickerView: could not create PortValue from string: \(selection) ... in choices: \(choices)")
        }
    }
    
    var body: some View {

        let binding: Binding<String> = createBinding(choiceDisplay, onSet)

        Picker(pickerLabel, selection: binding) {
            ForEach(pickerChoices, id: \.self) {
                StitchTextView(string: $0)
            }
        }
    }
}
