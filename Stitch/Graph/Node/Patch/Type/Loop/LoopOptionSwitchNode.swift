//
//  LoopOptionSwitchNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/2/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

@MainActor
func loopOptionSwitchNode(id: NodeId,
                          position: CGPoint = .zero,
                          zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values: (nil, [pulseDefaultFalse])
    )

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values: ("Option", [.number(0)])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .loopOptionSwitch,
        inputs: inputs,
        outputs: outputs)
}

// TODO: revisit how this works with indices
@MainActor
func loopOptionSwitchEval(node: PatchNode,
                          graphStep: GraphStepState) -> ImpureEvalResult {

    let inputsValues = node.inputs
    let graphTime = graphStep.graphTime

    let inputLoop = inputsValues.first!
    
    let previousValue: Double = node.outputs.first?.first?.getNumber ?? .zero

    // log("loopOptionSwitchEval: inputLoop: \(inputLoop)")
    // log("loopOptionSwitchEval: graphTime: \(graphTime)")
    // Must: find the
    // The output of the eval is always a "single" number: the index of the last pulse in the input-loop
    // But we must also return UI pulses for any of the indices in the input that pulsed.

    // If still nil at end of iterating through the loop,
    // then we didn't have any pulses at all.
    var lastPulsedIndex: Int?
    inputLoop.enumerated().forEach { x in
        let value: PortValue = x.element
        let index: Int = x.offset

        // log("loopOptionSwitchEval: value: \(value)")
        // log("loopOptionSwitchEval: index: \(index)")

        if let pulseAt = value.getPulse, pulseAt.shouldPulse(graphTime) {
            // log("loopOptionSwitchEval: had pulse!")
            lastPulsedIndex = index
        }
    }

    let _shouldPulse = lastPulsedIndex.isDefined

    if _shouldPulse {
        // log("loopOptionSwitchNodeEval: had pulse")
        // An input can only be manually pulsed if it had no incoming edge;
        // i.e. we can only have a scalar value in this case,
        // so the "which index pulsed?" output must be 0.
        let finalIndex: Int = lastPulsedIndex ?? 0

        let pulsedIndexOutput: PortValues = [.number(finalIndex.toDouble)]

        return ImpureEvalResult(
            outputsValues: [pulsedIndexOutput])
    } else {
        // log("loopOptionSwitchNodeEval: no pulse...")
        return ImpureEvalResult(outputsValues: [[.number(previousValue)]])
//        return .noChange(node,
//                         // only one possible node type
//                         defaultOutputsValues: [[.number(0)]])
    }
}
