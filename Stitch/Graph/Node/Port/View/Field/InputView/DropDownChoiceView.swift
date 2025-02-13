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
    
    let id: InputCoordinate
    
    let layerInputObserver: LayerInputObserver?
    
    @Bindable var graph: GraphState
    
    let choiceDisplay: String
    let choices: PortValues
    let isFieldInsideLayerInspector: Bool
    let isSelectedInspectorRow: Bool
    
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

    @MainActor
    var finalChoiceDisplay: String {
        self.hasHeterogenousValues ? .HETEROGENOUS_VALUES : self.choiceDisplay
    }
    
    var body: some View {
        Menu {
            StitchPickerView(input: id,
                             choices: choices,
                             choiceDisplay: finalChoiceDisplay,
                             isFieldInsideLayerInspector: isFieldInsideLayerInspector)
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

    let input: InputCoordinate
    let choices: PortValues
    let choiceDisplay: String // current choice
    let isFieldInsideLayerInspector: Bool

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
            pickerOptionSelected(input: input,
                                 choice: _selection,
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

@MainActor
func pickerOptionSelected(input: InputCoordinate, 
                          choice: PortValue,
                          isFieldInsideLayerInspector: Bool) {
    dispatch(PickerOptionSelected(input: input,
                                  choice: choice,
                                  isFieldInsideLayerInspector: isFieldInsideLayerInspector))
}
