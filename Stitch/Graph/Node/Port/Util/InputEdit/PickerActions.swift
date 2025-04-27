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
struct PickerOptionSelected: StitchDocumentEvent {
    
    let id: InputCoordinate
    let choice: PortValue
    let isFieldInsideLayerInspector: Bool
    var isPersistence: Bool = true
    
    @MainActor
    func handle(state: StitchDocumentViewModel) {
        
        let graph = state.visibleGraph
        
        guard let rowObserver = graph.getInputRowObserver(id) else {
            return
        }
        
        graph.handleInputEditCommitted(
            input: rowObserver,
            value: choice,
            activeIndex: state.activeIndex,
            isFieldInsideLayerInspector: isFieldInsideLayerInspector)
        
        if isPersistence {
            graph.encodeProjectInBackground()
        }
    }
}
