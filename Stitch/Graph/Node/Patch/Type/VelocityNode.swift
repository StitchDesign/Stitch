//
//  VelocityNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/19/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct VelocityNode: PatchNodeDefinition {
    static let patch = Patch.velocity

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(0)],
                    label: ""
                )
            ],
            outputs: [
                .init(
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
func velocityEval(node: PatchNode) -> EvalResult {
    // log("velocityEval called: \(node.id)")

    // current - previous = output

    // where `current` is value in loop index slot THIS frame
    // and `previous` is value in same loop index slot from PREVIOUS frame
    node.loopedEval(ComputedNodeState.self) { values, computedState, _ in
        let valueAtCurrentFrame: Double = values.first?.getNumber ?? .zero
        let valueAtPreviousFrame: Double = computedState.previousValue?.getNumber ?? .zero
        let newValue: Double = valueAtCurrentFrame - valueAtPreviousFrame
        
        // Save next previous value
        computedState.previousValue = .number(valueAtCurrentFrame)
        return [PortValue.number(newValue)]
    } // ?? [[numberDefaultFalse]]
}
