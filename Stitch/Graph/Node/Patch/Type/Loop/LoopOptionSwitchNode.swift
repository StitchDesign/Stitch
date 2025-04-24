//
//  LoopOptionSwitchNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/2/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct LoopOptionSwitchNode: PatchNodeDefinition {
    static let patch = Patch.loopOptionSwitch
    
    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(inputs: [
            .init(defaultType: .pulse,
                 isTypeStatic: true)
        ],
              outputs: [
                .init(label: "Option",
                      value: .number(.zero))
              ])
    }
    
    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        ComputedNodeState()
    }
}

// TODO: revisit how this works with indices
@MainActor
func loopOptionSwitchEval(node: PatchNode,
                          graphStep: GraphStepState) -> EvalResult {
    guard let computedState = node.ephemeralObservers?.first as? ComputedNodeState else {
        fatalErrorIfDebug()
        return .init(outputsValues: node.defaultOutputsList)
    }
    
    let newValue = loopOptionSwitchEvalOp(node: node,
                                          graphTime: graphStep.graphTime,
                                          computedState: computedState)
    computedState.previousValue = newValue
    return .init(outputsValues: [[newValue]])
}

@MainActor
func loopOptionSwitchEvalOp(node: PatchNode,
                            graphTime: TimeInterval,
                            computedState: ComputedNodeState) -> PortValue {

    let inputsValues = node.inputs

    guard let inputLoop = inputsValues.first else {
        fatalErrorIfDebug()
        return .number(.zero)
    }
    
    let previousValue: Double = computedState.previousValue?.getNumber ?? .zero

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

        let pulsedIndexOutput = PortValue.number(finalIndex.toDouble)

        return pulsedIndexOutput
    } else {
        // log("loopOptionSwitchNodeEval: no pulse...")
        return .number(previousValue)
    }
}
