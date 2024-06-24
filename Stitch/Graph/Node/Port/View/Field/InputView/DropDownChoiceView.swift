//
//  DropDownChoiceView.swift
//  prototype
//
//  Created by Christian J Clampitt on 5/3/22.
//

import SwiftUI
import StitchSchemaKit

// Picker that chooses between MacOS vs iOS dropdowns
struct DropDownChoiceView: View {

    let id: InputCoordinate
    let choiceDisplay: String
    let choices: PortValues

    var body: some View {
        Menu {
            StitchPickerView(input: id,
                             choices: choices,
                             choiceDisplay: choiceDisplay)
        } label: {
            StitchTextView(string: choiceDisplay)
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

    var body: some View {

        let onSet = { (selection: String) in

            // TODO: make these logic cleaner? pass PortValue instead of String to Picker ?
            let _selection = choices.first(where: { $0.display == selection })

            if let _selection = _selection {
                pickerOptionSelected(input: input, choice: _selection)
            } else {
                log("StitchPickerView: could not create PortValue from string: \(selection) ... in choices: \(choices)")
            }
        }

        let binding: Binding<String> = createBinding(choiceDisplay, onSet)

        Picker(pickerLabel, selection: binding) {
            ForEach(pickerChoices, id: \.self) {
                StitchTextView(string: $0)
            }
        }
    }
}

@MainActor
func pickerOptionSelected(input: InputCoordinate, choice: PortValue) {
    dispatch(PickerOptionSelected(input: input,
                                  choice: choice))
}
