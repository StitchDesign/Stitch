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
        log("ReduxFieldFocused: focusedField: \(focusedField)")
        log("ReduxFieldFocused: state.reduxFocusedField was: \(state.reduxFocusedField)")
        state.reduxFocusedField = focusedField
    }
}

struct ReduxFieldDefocused: GraphUIEvent {
    let focusedField: FocusedUserEditField
    
    func handle(state: GraphUIState) {
        log("ReduxFieldDefocused: focusedField: \(focusedField)")
        log("ReduxFieldDefocused: state.reduxFocusedField: \(state.reduxFocusedField)")
        if state.reduxFocusedField == focusedField {
            //             log("ReduxFieldDefocused: will set focused field nil")
            state.reduxFocusedField = nil
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
