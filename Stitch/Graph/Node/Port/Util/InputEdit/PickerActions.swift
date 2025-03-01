//
//  PickerActions.swift
//  Stitch
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
    let isFieldInsideLayerInspector: Bool
    var isPersistence = true

    func handle(state: GraphState) -> GraphResponse {
        //        log("PickerOptionSelected: input: \(input)")`
        //        log("PickerOptionSelected: choice: \(choice)")
        state.handleInputEditCommitted(
            input: input,
            value: choice,
            isFieldInsideLayerInspector: isFieldInsideLayerInspector)
        
        return .persistenceResponse
    }
}
