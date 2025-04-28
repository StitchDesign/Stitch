//
//  PulseNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/7/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct PulseNode: PatchNodeDefinition {
    static let patch = Patch.pulse

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.bool(false)],
                    label: "On/Off"
                )
            ],
            outputs: [
                .init(
                    label: "Turned On",
                    type: .pulse
                ),
                .init(
                    label: "Turned Off",
                    type: .pulse
                )
            ]
        )
    }

    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        let prevValue: PortValue = .bool(false)
        return ComputedNodeState(
            previousValue: prevValue)
    }
    
    static let defaultOutputs: PortValuesList = [[.pulse(.zero), .pulse(.zero)]]
}

@MainActor
func pulseNodeEval(node: PatchNode,
                   // only needs graphTime
                   state: GraphStepState) -> EvalResult {
    let graphTime = state.graphTime
    
    return node.loopedEval(ComputedNodeState.self) { values, computedState, _ -> PortValues in
        let newVal = values.first?.getBool ?? false
        let computedStates = node.computedStates
        
        let output: PortValue = values[safe: 1] ?? pulseDefaultFalse
        let output2: PortValue = values[safe: 2] ?? pulseDefaultFalse
        
        let firstCoordinate = InputCoordinate(portId: 0, nodeId: node.id)
        let prevVal = computedState.previousValue?.getBool ?? false
        
        // Set next previous values
        computedState.previousValue = .bool(newVal)
        
        if newVal && !prevVal {
            //            log("pulseNodeClosure: false -> true")
            return [
                .pulse(graphTime),
                output2
            ]
        }
        // ie turned off: was true, is now false
        else if !newVal && prevVal {
            //            log("pulseNodeClosure: true -> false")
            return [
                output,
                .pulse(graphTime)
            ]
        }
        // no change
        else {
            //            log("pulseNodeClosure: no change")
            return [
                output,
                output2
            ]
        }
    }
}
