//
//  RandomNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct RandomPatchNode: PatchNodeDefinition {
    static let patch = Patch.random

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.pulse(0)],
                    label: "Randomize"
                ),
                .init(
                    label: "Start Value",
                    defaultType: .number
                ),
                .init(
                    defaultValues: [.number(50)],
                    label: "End Value"
                )
            ],
            outputs: [
                .init(
                    label: "Value",
                    type: .number
                )
            ]
        )
    }

    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        ComputedNodeState()
    }
}

@MainActor
func randomEval(node: PatchNode,
                graphStep: GraphStepState) -> ImpureEvalResult {

    let outputsValues: PortValuesList = node.outputs
    let graphTime: TimeInterval = graphStep.graphTime

    let op = randomOpClosure(graphTime: graphTime)

    return pulseEvalUpdate(
        node.inputs,
        [outputsValues.first ?? [.number(.zero)]],
        op)
}

func randomOpClosure(graphTime: TimeInterval) -> PulseOperationT {
    
    return { (values: PortValues) -> ImpureEvalOpResult in
        
        let pulseAt: TimeInterval = values.first?.getPulse ?? .zero
        let start = values[1].getNumber ?? .zero
        let end = values[2].getNumber ?? .zero
        let pulsed = pulseAt.shouldPulse(graphTime)
        let willRegenRandom = (pulsed || graphTime == .zero) && start < end
        
        // old output was added on as 4th item among 'indexed inputs'
        guard let oldOutput = values[safe: 3],
              !willRegenRandom else {
            return .init(outputs: [.number(Double.random(in: start...end))])
        }
        
        return .init(outputs: [oldOutput])
    }
}
