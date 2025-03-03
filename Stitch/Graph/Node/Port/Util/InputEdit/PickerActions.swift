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
extension GraphState {
    @MainActor
    func pickerOptionSelected(rowObserver: InputNodeRowObserver,
                              choice: PortValue,
                              isFieldInsideLayerInspector: Bool,
                              isPersistence: Bool = true) {
        //        log("PickerOptionSelected: input: \(input)")`
        //        log("PickerOptionSelected: choice: \(choice)")
        self.handleInputEditCommitted(
            input: rowObserver,
            value: choice,
            isFieldInsideLayerInspector: isFieldInsideLayerInspector)
        
        if isPersistence {
            self.encodeProjectInBackground()            
        }
    }
}
