//
//  PreviewLayerTextUtils.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import StitchSchemaKit

struct ReduxFieldFocused: GraphUIEvent {
    let focusedField: FocusedUserEditField

    func handle(state: GraphUIState) {
        state.reduxFieldFocused(focusedField: focusedField)
    }
}

extension GraphUIState {
    func reduxFieldFocused(focusedField: FocusedUserEditField) {
        log("reduxFieldFocused: focusedField: \(focusedField)")
        log("reduxFieldFocused: self.reduxFocusedField was: \(self.reduxFocusedField)")
        self.reduxFocusedField = focusedField
    }
}

struct ReduxFieldDefocused: GraphUIEvent {
    let focusedField: FocusedUserEditField
    
    func handle(state: GraphUIState) {
        state.reduxFieldDefocused(focusedField: focusedField)
    }
}

extension GraphUIState {
    func reduxFieldDefocused(focusedField: FocusedUserEditField) {
        log("reduxFieldDefocused: focusedField: \(focusedField)")
        log("reduxFieldDefocused: self.reduxFocusedField was: \(self.reduxFocusedField)")
        if self.reduxFocusedField == focusedField {
            self.reduxFocusedField = nil
        }
    }
}

// just directly update the output; don't even need the `edit` saved on the text-field layer view model?
//
struct TextFieldInputEdited: ProjectEnvironmentEvent {

    let id: PreviewCoordinate
    let newEdit: String

    func handle(graphState: GraphState,
                environment: StitchEnvironment) -> GraphResponse {

        // set the newEdit in the text field layer node's output (id.nodeId) at the given loop index (id.loopIndex)

        // log("TextFieldInputEdited called: id: \(id)")

        guard let layerNodeViewModel = graphState.getLayerNode(id: id.layerNodeId.id)?.layerNode,
              let layerViewModelAtIndex = layerNodeViewModel.previewLayerViewModels[safe: id.loopIndex] else {
            log("TextFieldInputEdited: could not find layer node view model for \(id.layerNodeId) or layer view model for loop-index \(id.loopIndex)")
            return .noChange
        }

        layerViewModelAtIndex.text = .string(.init(newEdit))

        graphState.calculate(id.layerNodeId.id)

        return .noChange
    }
}
