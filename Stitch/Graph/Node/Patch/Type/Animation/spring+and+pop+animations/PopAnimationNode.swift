//
//  PopAnimationNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/5/23.
//

import Foundation
import StitchSchemaKit
import SwiftUI

let sampleBounciness: Double = 5
let sampleSpeed: Double = 10

struct PopAnimationNode: PatchNodeDefinition {
    static let patch = Patch.popAnimation

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
                    defaultValues: [.number(5)],
                    label: "Bounciness",
                    isTypeStatic: true
                ),
                .init(
                    defaultValues: [.number(10)],
                    label: "Speed",
                    isTypeStatic: true
                )
            ],
            outputs: [
                .init(
                    label: "",
                    type: type ?? .number
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
func popAnimationEval(node: PatchNode,
                      graphStepState: GraphStepState) -> ImpureEvalResult {
    
    node.loopedEval(ComputedNodeState.self) { values, computedState, _ in
        switch node.userVisibleType! {
        case .number:
            return springAnimationNumberOp(
                    values: values,
                    computedState: computedState,
                    graphTime: graphStepState.graphTime,
                    isPopAnimation: true)
        case .position:
            return springAnimationPositionOp(
                    values: values,
                    computedState: computedState,
                    graphTime: graphStepState.graphTime,
                    isPopAnimation: true)
        default:
            fatalError()
        }
    }
    .toImpureEvalResult()
}
