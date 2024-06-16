//
//  LoopShuffleNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/2/22.
//

import Foundation
import StitchSchemaKit

@MainActor
func loopShuffleNode(id: NodeId,
                     position: CGSize = .zero,
                     zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            ("Loop", [.number(0)]),
        ("Shuffle", [pulseDefaultFalse])
    )

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values:
            ("Loop", [.number(0)])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .loopShuffle,
        inputs: inputs,
        outputs: outputs)
}

@MainActor
func loopShuffleEval(node: PatchNode,
                     graphStep: GraphStepState) -> EvalResult {

    let inputsValues = node.inputs
    let graphTime = graphStep.graphTime

    // Suppose the inputLoop is a loop of pulses;
    // we shuffle the entire loop when ANY of the indices pulses.
    let inputLoop = inputsValues.first ?? [.number(.zero)]
    let shuffleLoop = inputsValues[safe: 1] ?? [pulseDefaultFalse]

    let hadPulseInShuffleLoop = shuffleLoop.someIndexPulsed(graphTime)
    if hadPulseInShuffleLoop {
        return [inputLoop.shuffled()].createPureEvalResult()
    }

    log("loopShuffleEval: no change")
    // So just pass on the input loop
    return [inputLoop].createPureEvalResult()
}
