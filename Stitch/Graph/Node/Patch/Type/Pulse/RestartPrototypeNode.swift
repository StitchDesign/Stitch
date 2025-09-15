//
//  RestartPrototypeNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct RestartPrototypePatchNode: PatchNodeDefinition {
    static let patch = Patch.restartPrototype
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [pulseDefaultFalse],
                    label: "Restart"
                )
            ],
            outputs: []
        )
    }
}

// a pulse-receiving node like counter
// not outputs, only inputs?
// it's evaluation will be the same as body of 'handleGraphReset'

// doesn't have outputs, and only maybe returns side effect.
@MainActor
func restartPrototypeEval(node: PatchNode,
                          graphStep: GraphStepState) -> ImpureEvalResult {

    let graphTime: TimeInterval = graphStep.graphTime

    // only one input (loop of pulses);
    // if any indices have pulses, we return effect.
    let receivedPulse: Bool = (node.inputs.first ?? [pulseDefaultFalse]).contains { (value: PortValue) -> Bool in
        if let pulseAt = value.getPulse {
            return pulseAt.shouldPulse(graphTime)
        }
        return false
    }

    guard receivedPulse else {
        // log("restartPrototypeEval: no pulse")
        // Has no outputs, so nothing to do here
        return .noChange(node)
    }

    // log("restartPrototypeEval: had pulse")
    Task { @MainActor in
        dispatch(PrototypeRestartedAction())
    }
    
    return ImpureEvalResult(
        outputsValues: [])
}
