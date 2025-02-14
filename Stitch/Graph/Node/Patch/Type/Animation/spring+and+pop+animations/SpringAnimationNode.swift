//
//  SpringAnimationNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI

let sampleMass: Double = 1
let sampleTension: Double = 130.5
let sampleFriction: Double = 18.85

struct SpringAnimationNode: PatchNodeDefinition {
    static let patch = Patch.springAnimation

    static private let _defaultUserVisibleType: UserVisibleType = .number
    static let defaultUserVisibleType: UserVisibleType? = Self._defaultUserVisibleType

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(0)],
                    label: "Number"
                ),
                .init(
                    defaultValues: [.number(1)],
                    label: "Mass",
                    isTypeStatic: true
                ),
                .init(
                    defaultValues: [.number(130.5)],
                    label: "Stiffness",
                    isTypeStatic: true
                ),
                .init(
                    defaultValues: [.number(18.85)],
                    label: "Damping",
                    isTypeStatic: true
                )
            ],
            outputs: [
                .init(
                    label: "",
                    type: .number
                )
            ]
        )
    }

    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        // If we have existing inputs, then we're deserializing,
        // and should base internal state and starting outputs on those inputs.
        let state: SpringAnimationState = .defaultFromNodeType(Self._defaultUserVisibleType)
        return ComputedNodeState(springAnimationState: state)
    }
}

@MainActor
func springAnimationEval(node: PatchNode,
                         graphStepState: GraphStepState) -> ImpureEvalResult {
    
    node.loopedEval(ComputedNodeState.self) { values, computedState, _ in
        switch node.userVisibleType {
        case .number:
            springAnimationNumberOp(
                values: values,
                computedState: computedState,
                graphTime: graphStepState.graphTime,
                isPopAnimation: false)
        case .position:
            springAnimationPositionOp(
                values: values,
                computedState: computedState,
                graphTime: graphStepState.graphTime,
                isPopAnimation: false)
        default:
            fatalError()
        }
    }
    .toImpureEvalResult()
}

