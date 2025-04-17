//
//  StopwatchNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/29/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct StopwatchNode: PatchNodeDefinition {
    static let patch = Patch.stopwatch

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.pulse(0)],
                    label: "Start"
                ),
                .init(
                    defaultValues: [.pulse(0)],
                    label: "Stop"
                ),
                .init(
                    defaultValues: [.pulse(0)],
                    label: "Reset"
                )
            ],
            outputs: [
                .init(
                    label: "Time",
                    type: .number
                )
            ]
        )
    }

    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        ComputedNodeState(stopwatchIsRunning: false)
    }
}

func stopwatchOpClosure(values: PortValues,
                        graphTime: TimeInterval,
                        computedState: ComputedNodeState) -> PortValues {

    //        log("stopwatchOpClosure: values: \(values)")
    //        log("stopwatchOpClosure: isRunning: \(isRunning)")
    
    let currentOutput: PortValue = values[safe: 3] ?? numberDefaultFalse
    
    let noChange = [currentOutput]
    
    let startPulsed = values[safe: 0]?.getPulse?.shouldPulse(graphTime) ?? false
    let endPulsed = values[safe: 1]?.getPulse?.shouldPulse(graphTime) ?? false
    let resetPulsed = values[safe: 2]?.getPulse?.shouldPulse(graphTime) ?? false
    
    // we simply add the time diff to the current output,
    // in order to get new output
    // NOTE: THIS IS A TIME-DIFF (A NUMBER), NOT A PULSE
    let currentOutputTime: Double = currentOutput.getNumber ?? .zero
    
    /*
     For output, Rules:
     - reset takes predence
     - if start and stop at same time, then no change
     */
    if resetPulsed {
        return [.number(.zero)]
    } else if startPulsed && endPulsed {
        return noChange
    } else if endPulsed {
        //            log("stopwatchOpClosure: end pulse")
        
        computedState.stopwatchIsRunning = false
        return [currentOutput]
    } else if startPulsed {
        // Reset timestamp to track when stopwatch was started
        computedState.stopwatchStartGraphTime = graphTime
        
        if currentOutputTime == .zero {
            //                log("stopwatchOpClosure: FRESH START")

            computedState.stopwatchIsRunning = true

            // ie the first time we've pressed start,
            // so we use .zero
            return [.number(.zero)]
            
        } else {
            //                log("stopwatchOpClosure: RESUMING")
            
            computedState.stopwatchIsRunning = true
            
            // ie resuming a paused stopwatch
            // means we must start from current output
            return [.number(currentOutputTime)]
        }
    } else if computedState.stopwatchIsRunning,
              let stopwatchStartGraphTime = computedState.stopwatchStartGraphTime {
        let newTime = graphTime - stopwatchStartGraphTime
        
        computedState.stopwatchIsRunning = true
        
        return [.number(newTime)]
    } else {
        //            log("stopwatchOpClosure: unknown case")
        return noChange
    }
}

@MainActor
func stopwatchEval(node: PatchNode,
                   graphStep: GraphStepState) -> EvalResult {
    node.loopedEval(ComputedNodeState.self) { values, computedState, _ in
        stopwatchOpClosure(values: values,
                           graphTime: graphStep.graphTime,
                           computedState: computedState)
    } // ?? [numberDefaultFalse]
}
