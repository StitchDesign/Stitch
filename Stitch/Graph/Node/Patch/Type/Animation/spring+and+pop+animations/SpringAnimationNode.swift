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
                    label: "Value"
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
func springAnimationEval(node: NodeViewModel,
                         graphStepState: GraphStepState) -> EvalResult {
    springAnimationEval(node: node,
                        graphTime: graphStepState.graphTime,
                        outputIndex: 4,
                        isPopAnimation: false)
}

@MainActor
func springAnimationEval(node: NodeViewModel,
                         graphTime: TimeInterval,
                         outputIndex: Int,
                         isPopAnimation: Bool) -> EvalResult {
    assertInDebug(node.userVisibleType != nil)
    let nodeType = node.userVisibleType ?? .number
    
    return node.loopedEval(SpringAnimationState.self) { values, animationObserver, _ -> NodeEvalOpResult in
        
        // If node type changed, exit and reset spring state
        guard values.first?.toNodeType == values[safe: outputIndex]?.toNodeType else {
            animationObserver.reset()
            return .init(values: [values.first ?? nodeType.defaultPortValue])
        }
        
        var willRunAgain = false
        let currentSpringStates = animationObserver.springStates

        // Number/layer dimension type is the only type that doesn't unpack
        let toValues = (values.first ?? .number(.zero)).unpackValues() ??
            [.number(values.first?.getNumber ?? .zero)]
        let currentOutputs = values[safe: outputIndex]?.unpackValues() ??
            [.number(values[safe: outputIndex]?.getNumber ?? .zero)]
        
        // Reset spring states in class before eval
        animationObserver.springStates = []
        
        // Returns unpacked numbers to later be packed into PortValues
        let outputResults: PortValues = zip(toValues, currentOutputs)
            .enumerated().map { index, springValues in
                // Start with unpacking layer dimension first in case of position
                guard let toValue = springValues.0.getLayerDimension?.getNumber else {
                    // Return whatever our input is to support non-number layer dimensions
                    animationObserver.springStates.append(nil)
                    return springValues.0
                }
                
                let currentOutputValue = springValues.1
                
                let result = springAnimationOp(toValue: toValue,
                                               values: values,
                                               currentOutputValue: currentOutputValue.getLayerDimension?.getNumber ?? .zero,
                                               state: currentSpringStates[safe: index] ?? nil,
                                               graphTime: graphTime,
                                               isPopAnimation: isPopAnimation)
                
                switch result.resultType {
                case .complete:
                    // Nil spring state indicates complete
                    animationObserver.springStates.append(nil)
                    return PortValue.number(result.result)
                    
                case .inProgress(let springValueState):
                    // mark node as needing another eval run
                    willRunAgain = true
                    
                    animationObserver.springStates.append(springValueState)
                    return PortValue.number(result.result)
                }
            }
        
        let packedOutput = outputResults.packValues(type: nodeType) ?? outputResults.first ?? .number(.zero)
        
        return NodeEvalOpResult(values: [packedOutput],
                                willRunAgain: willRunAgain)
    }
}
