//
//  RepeatingPulsePatchNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// https://origami.design/documentation/patches/builtin.counter.html
struct RepeatingPulseNode: PatchNodeDefinition {
    static let patch = Patch.repeatingPulse

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(3)],
                    label: "Frequency"
                )
            ],
            outputs: [
                .init(
                    label: "",
                    type: .pulse
                )
            ]
        )
    }

    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        ComputedNodeState()
    }
}

// NOTE: Cannot receive manual pulses because has no pulse inputs
@MainActor
func repeatingPulseEval(node: PatchNode,
                        graphState: GraphState) -> ImpureEvalResult {
    let graphTime = graphState.graphStepState.graphTime
            
    return node.loopedEvalOutputsPersistence(graphTime: graphTime) { values, computedState in
        // to determine whether it's time to pulse or not,
        // will have to look at the existing outputs' indices' .pulse(lastAt)
        let frequency: Double = values.first?.getNumber ?? 0.0

        // Look at the *output's* index's `pulsedAt`;
        // we need to know if it's been long enough since last pulse.
        let pulseAt: TimeInterval = computedState.previousValue?.getPulse ?? .zero

        let _shouldPulse = shouldPulse(currentTime: graphTime,
                                       lastTimePulsed: pulseAt,
                                       pulseEvery: frequency)

        if frequency > 0 && _shouldPulse {
            // We pulsed, so update pulse-time
            return .pulse(graphTime)
        } else {
            return .pulse(pulseAt)
        }
    }
}
