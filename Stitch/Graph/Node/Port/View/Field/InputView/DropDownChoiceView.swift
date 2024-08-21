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
    
    @Bindable var graph: GraphState
    
    let choiceDisplay: String
    let choices: PortValues
    
    // TODO: if this is a dropdown for a multiselect layer, then use "Multi" instead of `choiceDisplay`
    // TODO: handle properly by field, not whole input
    @MainActor
    var hasHeterogenousValues: Bool {
        /*
         Only relevant when this field is:
         - for a layer
         - in the layer inspector
         - and we have multiple layers selected
         */
//        let isLayer = inputField.rowViewModelDelegate?.id.portType.keyPath.isDefined ?? false
        
        guard let layerInput = id.keyPath?.layerInput, // inputField.rowViewModelDelegate?.id.portType.keyPath?.layerInput,
              let multiselectObserver = graph.graphUI.propertySidebar.layerMultiselectObserver,
              let layerMultiselectInput: LayerMultiselectInput = multiselectObserver.inputs.get(layerInput) else {
            log("DropDownChoiceView: hasHeterogenousValues: guard")
            return false
        }
        
        let fieldsWithHeterogenousValues = layerMultiselectInput.hasHeterogenousValue
        
        if fieldsWithHeterogenousValues.contains(0) {
            log("DropDownChoiceView: hasHeterogenousValues: heterogenous values for layerInput \(layerInput)")
            return true
        } else {
            return false
        }
            
//        if layerMultiselectInput.hasHeterogenousValue {
//            log("DropDownChoiceView: hasHeterogenousValues: heterogenous values for \(layerInput)")
//            return true
//        }
//        
//        return layerMultiselectInput.hasHeterogenousValue
    }

    @MainActor
    var finalChoiceDisplay: String {
        self.hasHeterogenousValues ? .HETEROGENOUS_VALUES : self.choiceDisplay
    }
    
    var body: some View {
        Menu {
            StitchPickerView(input: id,
                             choices: choices,
//                             choiceDisplay: choiceDisplay)
                             choiceDisplay: finalChoiceDisplay)
        } label: {
//            StitchTextView(string: choiceDisplay)
            StitchTextView(string: finalChoiceDisplay)
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
