//
//  PulseActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/30/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension GraphState {    
    @MainActor
    func pulseValueButtonClicked(_ inputObserver: InputNodeRowObserver,
                                 canvasItemId: CanvasItemId?) {
        
        // Select canvas if associated here
        if let canvasItemId = canvasItemId {
            self.selectSingleCanvasItem(canvasItemId)
        }
        
        inputObserver.updateValuesInInput([.pulse(self.graphStepState.graphTime)])
        
        self.scheduleForNextGraphStep(inputObserver.id.nodeId)
    }
}

func shouldPulse(currentTime: TimeInterval,
                 lastTimePulsed: TimeInterval,
                 pulseEvery: TimeInterval) -> Bool {

    let diff = currentTime - lastTimePulsed

    //    log("shouldPulse: currentTime: \(currentTime)")
    //    log("shouldPulse: lastTimePulsed: \(lastTimePulsed)")
    //    log("shouldPulse: diff: \(diff)")
    //    log("shouldPulse: pulseEvery: \(pulseEvery)")

    return diff >= pulseEvery
}
