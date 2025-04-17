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
        SpringAnimationState()
    }
}

@MainActor
func popAnimationEval(node: PatchNode,
                      graphStepState: GraphStepState) -> ImpureEvalResult {
    springAnimationEval(node: node,
                        graphTime: graphStepState.graphTime,
                        outputIndex: 3,
                        isPopAnimation: true)
}
