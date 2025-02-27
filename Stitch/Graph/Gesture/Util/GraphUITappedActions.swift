//
//  GraphUITappedActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/17/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// More like: `ResetGraphUIEdits`
extension GraphState {
    @MainActor
    func graphTapped(graphUI: GraphUIState) {
        log("GraphTappedAction called")
        self.resetAlertAndSelectionState(graphUI: graphUI)
    }
}

struct GraphDoubleTappedAction: StitchDocumentEvent {
    let location: CGPoint
    
    func handle(state: StitchDocumentViewModel) {
        log("GraphDoubleTappedAction: location: \(location)")
        
        state.graphUI.toggleInsertNodeMenu()
        
//        if !state.llmRecording.isRecording {
        // Do not set double-tap location if we're actively recording
        state.graphUI.doubleTapLocation = location
//        }
        
        // log("GraphDoubleTappedAction: state.doubleTapLocation is now: \(state.doubleTapLocation)")
    }
}
