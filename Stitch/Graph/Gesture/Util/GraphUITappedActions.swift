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
struct GraphTappedAction: ProjectEnvironmentEvent {
    func handle(graphState: GraphState,
                computedGraphState: ComputedGraphState,
                environment: StitchEnvironment) -> GraphResponse {
        // log("GraphTappedAction called")
        graphState.resetAlertAndSelectionState()
        return .noChange
    }
}

struct GraphDoubleTappedAction: GraphUIEvent {
    let location: CGPoint

    func handle(state: GraphUIState) {
        // log("GraphDoubleTappedAction called")
        state.toggleInsertNodeMenu()
        
        if !state.llmRecording.isRecording {
            // Do not set double-tap location if we're actively recording
            state.doubleTapLocation = location
        }
        
        // log("GraphDoubleTappedAction: state.doubleTapLocation is now: \(state.doubleTapLocation)")
    }
}

extension GraphMovementObserver {
    func centerViewOnNode(frame: CGRect,
                          position: CGPoint) {

        // the size of the screen and nodeView
        let newLocation = calculateMove(frame, position)
        self.localPosition = newLocation
        self.localPreviousPosition = newLocation
    }
}
