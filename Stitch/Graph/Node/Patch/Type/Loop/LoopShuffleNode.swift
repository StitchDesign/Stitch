//
//  LoopShuffleNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/2/22.
//

import Foundation
import StitchSchemaKit

struct LoopShuffleNode: PatchNodeDefinition {
    static let patch: Patch = .loopShuffle
    
    static let _defaultUserVisibleType: UserVisibleType = .number
    
    // overrides protocol
    static let defaultUserVisibleType: UserVisibleType? = Self._defaultUserVisibleType
    
    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(inputs: [
            .init(label: "Loop",
                  defaultType: Self._defaultUserVisibleType),
            .init(label: "Shuffle",
                  staticType: .pulse)
        ],
              outputs: [
                .init(label: "Loop", type: Self._defaultUserVisibleType),
              ])
    }
    
    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        MediaReferenceObserver()
    }    
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

    // log("loopShuffleEval: no change")
    // So just pass on the input loop
    return [inputLoop].createPureEvalResult()
}
