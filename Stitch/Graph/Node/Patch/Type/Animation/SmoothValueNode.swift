//
//  SmoothValueNode.swift
//  prototype
//
//  Created by Christian J Clampitt on 7/19/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct SmoothValueNode: PatchNodeDefinition {
    static let patch = Patch.smoothValue

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(0)],
                    label: "Value"
                ),
                .init(
                    defaultValues: [.number(0)],
                    label: "Hysteresis"
                ),
                .init(
                    defaultValues: [.pulse(0)],
                    label: "Reset"
                )
            ],
            outputs: [
                .init(
                    label: "Progress",
                    type: .number
                )
            ]
        )
    }

    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        let state = SmoothValueAnimationState()
        return ComputedNodeState(smoothValueAnimationState: state)
    }
}

// TODO: needs to accept manual pulse
@MainActor
func smoothValueEval(node: PatchNode,
                     state: GraphStepState) -> ImpureEvalResult {
    node.loopedEval(ComputedNodeState.self) { values, computedState, _ in
        smoothValueAnimationEvalOp(
            values: values,
            computedState: computedState,
            nodeId: node.id,
            graphTime: state.graphTime)
    }
    .toImpureEvalResult()//defaultOutputs: [[numberDefaultFalse]])
}

// TODO: Remove SmoothValueAnimationState
struct SmoothValueAnimationState: Equatable, Codable, Hashable {
    // ie the `value` input on the Smooth Value node
    var toValue: Double = 0
}

// NOTE: SmoothValueAnimationState is NOT used in this calculation.
func smoothValueAnimationEvalOp(values: PortValues,
                                computedState: ComputedNodeState,
                                nodeId: UUID,
                                graphTime: TimeInterval) -> ImpureEvalOpResult {

    let toValue = values.first?.getNumber ?? .zero
    let hysterisis = values[safe: 1]?.getNumber ?? .zero
    let resetPulse = values[safe: 2]?.getPulse ?? .zero
    let previousOutput = values[safe: 3]?.getNumber ?? .zero
    var animationState = computedState.smoothValueAnimationState ?? .init()

    //    log("smoothValueAnimationEvalOp: toValue: \(toValue)")
    //    log("smoothValueAnimationEvalOp: currentOutput: \(previousOutput)")

    if resetPulse.shouldPulse(graphTime) {
        //        log("smoothValueAnimationEvalOp: had pulse")
        // If we receive a pulse, we immediately jump to our destination (the toValue),
        // and so don't need to run again.
        return .init(outputs: [.number(toValue)],
                     willRunAgain: false)
    }

    // Are we already at the destination?
    if areEquivalent(n: previousOutput, n2: toValue) {
        // log("smoothValueAnimationEvalOp: already at destination")
        return .init(outputs: [.number(previousOutput)],
                     willRunAgain: false)
    }
    //    else {
    //        log("smoothValueAnimationEvalOp: NOT already at destination")
    //    }

    let newValue: Double = calculateSmoothValueNewOutput(
        currentValueInput: toValue,
        previousOutput: previousOutput,
        hysteresis: hysterisis)

    let isSame: Bool = abs(toValue - newValue) < 0.00001


    computedState.smoothValueAnimationState = animationState
    
    if isSame {
        // log("smoothValueAnimationEvalOp: will NOT run again")

        // if isSame (ie 'close enough'), then need to return the 'destinination' toValue,
        // not the 'close enough' newValue
        return .init(outputs: [.number(toValue)],
                     willRunAgain: false)

    } else {
        // log("smoothValueAnimationEvalOp: will run again")
        return .init(outputs: [.number(newValue)],
                     willRunAgain: true)
    }
}

// https://origami.design/documentation/patches/builtin.smoothValue.html
// Adapted for our purpose:
// `new output = (previous output * hysteresis) + (current 'value' input * (1 - hysteresis))`
func calculateSmoothValueNewOutput(currentValueInput: Double,
                                   previousOutput: Double,
                                   hysteresis: Double) -> Double {

    let x = (previousOutput * hysteresis) + (currentValueInput * (1 - hysteresis))
    // log("calculateSmoothValueNewOutput: x: \(x)")
    return x
}
