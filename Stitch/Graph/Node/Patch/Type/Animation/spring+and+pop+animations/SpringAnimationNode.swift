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
        SpringAnimationState()
    }
}

@MainActor
func springAnimationEval(node: PatchNode,
                         graphStepState: GraphStepState) -> EvalResult {
    
    let outputIndex = 4
    var willRunAgain = false
    
    var evalResult = node.loopedEval(SpringAnimationState.self) { values, computedState, _ in
        switch node.userVisibleType {
        case .number:
            let result = springAnimationOp(toValue: values.first?.getNumber ?? .zero,
                                           values: values,
                                           currentOutputValue: values[safe: outputIndex]?.getNumber ?? .zero,
                                           state: computedState.springStates.first,
                                           graphTime: graphStepState.graphTime,
                                           isPopAnimation: false)
            switch result.resultType {
            case .complete:
                computedState.springStates = []
            case .inProgress(let springValueState):
                computedState.springStates = [springValueState]
                
                // Updates graph to run this node again on next graph step
                willRunAgain = true
            }
            
            return [.number(result.result)]

//        case .position:
//            springAnimationPositionOp(
//                values: values,
//                computedState: computedState,
//                graphTime: graphStepState.graphTime,
//                isPopAnimation: false)
        default:
            fatalError()
        }
    }
    
    evalResult.runAgain = willRunAgain
    return evalResult
}
