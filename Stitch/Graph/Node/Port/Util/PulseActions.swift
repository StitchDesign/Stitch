//
//  PulseActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/30/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// How long we have the pulse's port-value coercion effect before reverting.
// NOTE: converted later to milliseconds
let PULSE_LENGTH: Int = 100
//let PULSE_LENGTH: Int = 1
//let PULSE_LENGTH: Int = 10
//let PULSE_LENGTH: Int = 50
// let PULSE_LENGTH: Int = 36



// TODO: use Set<Coordinate>, instead of Dict<Coordinate: Bool> ?
// coordinate because could be output or input
// Coordinate: Pulsed?
// typealias FlashDict = [Coordinate: Bool]

typealias FlashSet = Set<Coordinate>

extension GraphState {    
    @MainActor
    func pulseValueButtonClicked(_ inputObserver: InputNodeRowObserver,
                                 canvasItemId: CanvasItemId?) {
        
        // Select canvas if associated here
        if let canvasItemId = canvasItemId {
            self.selectSingleCanvasItem(canvasItemId)
        }
        
        inputObserver.updateValues([.pulse(self.graphStepState.graphTime)])
        
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

// TODO: recalculate the graph only once for all pulses outputs,
// rather than recalculating the graph for every pulsed output.
struct ReversePulseCoercion: GraphEvent {
    
    let pulsedOutput: OutputCoordinate
    
    func handle(state: GraphState) {
        log("ReversePulseCoercion: for output \(pulsedOutput) BUT DOING NOTHING")
//        
////        return
//        
//        if pulsedOutput.nodeId.uuidString.contains("AA9C7B") {
//            log("ReversePulseCoercion: for output \(pulsedOutput)")
//            log("ReversePulseCoercion: graphTime: \(state.graphStepState.graphTime)")
//        }
//        
//        // Cannot recalculate full node in some examples (like delay node)
//        // so we just update downstream nodes
//        guard let node = state.getNodeViewModel(pulsedOutput.nodeId),
//              let currentOutputs = node.getOutputRowObserver(for: pulsedOutput.portType)?.allLoopedValues else {
//            //                  fatalErrorIfDebug("ReversePulseCoercion error: data not found.")
//            return
//        }
//        
//        // Reverse the values in the downstream inputs
//        let changedDownstreamInputIds = state
//            .updateDownstreamInputs(sourceNode: node,
//                                    flowValues: currentOutputs,
//                                    mediaList: nil,
//                                    upstreamOutputChanged: true, // True, since we reversed the pulse effect?
//                                    outputCoordinate: pulsedOutput)
//        let changedDownstreamNodeIds = Set(changedDownstreamInputIds.map(\.nodeId)).toSet
//        
//        log("ReversePulseCoercion: changedDownstreamNodeIds: \(changedDownstreamNodeIds) for output: \(pulsedOutput)")
//        
//        // Run the downstream inputs' node evals
//        state.scheduleForNextGraphStep(changedDownstreamNodeIds)
    } // handle
}

func pulseCoercionReversedEffect(_ pulsedOutput: OutputCoordinate) -> Effect {
    //    log("pulseCoercionReversedEffect called")
    return createDelayedEffect(
        delayInNanoseconds: Double(PULSE_LENGTH * nanoSecondsInMillisecond),
        action: ReversePulseCoercion(pulsedOutput: pulsedOutput))
}

func getPostPulseEffects(_ coordinate: Coordinate) -> SideEffects {
    //    log("getPostPulseEffects called")
    var effects = SideEffects()

    if case let .output(outputCoordinate) = coordinate {
        effects.append(pulseCoercionReversedEffect(outputCoordinate))
    }

    return effects
}
