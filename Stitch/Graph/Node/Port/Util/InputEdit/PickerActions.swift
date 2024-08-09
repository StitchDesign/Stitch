//
//  PickerActions.swift
//  prototype
//
//  Created by Christian J Clampitt on 3/1/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// this should be a single field committed
// ASSUMES: only single field values use dropdown
struct PickerOptionSelected: GraphEventWithResponse {

    let input: InputCoordinate
    let choice: PortValue
    var isPersistence = true

    func handle(state: GraphState) -> GraphResponse {
        //        log("PickerOptionSelected: input: \(input)")`
        //        log("PickerOptionSelected: choice: \(choice)")
        state.inputEditCommitted(input: input,
                                 value: choice)
        return .init(willPersist: isPersistence)
    }
}

/// Updates interaction-based nodes (scroll, drag, press) when a selected layer is changed.
struct InteractionPickerOptionSelected: GraphEventWithResponse {

    // interaction patch node's input
    let interactionPatchNodeInput: InputCoordinate

    // the new choice for assigned layer
    let layerNodeIdSelection: LayerNodeId?

    func handle(state: GraphState) -> GraphResponse {
        // log("InteractionPickerOptionSelected: input: \(interactionPatchNodeInput)")
        // log("InteractionPickerOptionSelected: layerNodeIdSelection: \(layerNodeIdSelection)")

        state.inputEditCommitted(
            input: interactionPatchNodeInput,
            value: .assignedLayer(layerNodeIdSelection))
        
        return .persistenceResponse
    }
}
