//
//  RestartPrototypeNode.swift
//  prototype
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// a pulse-receiving node like counter
// not outputs, only inputs?
// it's evaluation will be the same as body of 'handleGraphReset'
@MainActor
func restartPrototypeNode(id: NodeId,
                          position: CGSize = .zero,
                          zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(id: id, values: ("Restart", [pulseDefaultFalse])) // receives pulse

    // FAKE, HAS NO OUTPUTS!
    let outputs = fakeOutputs(id: id, offset: inputs.count)
    // toOutputs(id: id, offset: inputs.count, values: .none)

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .restartPrototype,
        inputs: inputs,
        outputs: outputs)
}

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
        log("restartPrototypeEval: no pulse")
        // Has no outputs, so nothing to do here
        return .noChange(node)
    }

    log("restartPrototypeEval: had pulse")
    let effect: Effect = { PrototypeRestartEffect() }
    return ImpureEvalResult(
        outputsValues: [],
        effects: [effect])
}

// Hack for effect above
struct PrototypeRestartEffect: GraphEvent {
    func handle(state: GraphState) {
        dispatch(PrototypeRestartedAction())
    }
}
