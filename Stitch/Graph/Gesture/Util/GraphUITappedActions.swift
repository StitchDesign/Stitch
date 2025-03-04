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
    func graphTapped(document: StitchDocumentViewModel) {
        log("GraphTappedAction called")
        self.resetAlertAndSelectionState(document: document)
    }
}

struct GraphDoubleTappedAction: StitchDocumentEvent {
    let location: CGPoint
    
    func handle(state: StitchDocumentViewModel) {
        log("GraphDoubleTappedAction: location: \(location)")
        
        state.toggleInsertNodeMenu()
        
//        if !state.llmRecording.isRecording {
        // Do not set double-tap location if we're actively recording
        state.insertNodeMenuState.doubleTapLocation = location
//        }
        
        // log("GraphDoubleTappedAction: state.doubleTapLocation is now: \(state.doubleTapLocation)")
    }
}
