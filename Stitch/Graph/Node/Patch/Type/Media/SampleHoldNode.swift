//
//  SampleHoldNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/20/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct SampleAndHoldNode: PatchNodeDefinition {
    static let patch = Patch.sampleAndHold

    static let defaultUserVisibleType: UserVisibleType? = .number

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(.zero)],
                    label: "Value"
                ),
                .init(
                    label: "Sample",
                    staticType: .bool
                ),
                .init(
                    label: "Reset",
                    staticType: .pulse
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
        ComputedNodeState()
    }
}

func sampleAndHoldOpClosure(graphTime: TimeInterval,
                            nodeType: NodeType) -> PulseOperationT {

    return { (values: PortValues) -> PulseOpResultT in
        // log("sampleAndHoldEval op: values: \(values)")
        
        let defaultFalseValue: PortValue = nodeType.defaultPortValue.defaultFalseValue
        // log("sampleAndHoldEval op: defaultFalseValue: \(defaultFalseValue)")
        
        let value: PortValue = values.first ?? defaultFalseValue
        // log("sampleAndHoldEval op: value: \(value)")
        
        let shouldSample: Bool = values[safe: 1]?.getBool ?? false
        let resetPulsePulseAt: TimeInterval = values[safe: 2]?.getPulse ?? .zero
        
        // If node type changed, then we need to change the type of the output as well,
        // but not having we already have a previous value,
        // so we need to change the type of the previous value.
        let nodeTypeChanged = values[safe: 3].map { (existingOutputValue: PortValue) in
            existingOutputValue.toNodeType != nodeType
        } ?? false
        
        // Use previous output, or if there is none yet, use first input
        var prevValue: PortValue = values[safe: 3] ?? defaultFalseValue
        // log("sampleAndHoldEval op: prevValue: \(prevValue)")
        
        if nodeTypeChanged {
            prevValue = defaultFalseValue
            // log("sampleAndHoldEval op: prevValue changed: \(prevValue)")
        }
        
        let resetPulsed = resetPulsePulseAt == graphTime
        
        if shouldSample {
            // log("sampleAndHoldEval op: Will sample: value: \(value)")
            return PulseOpResultT(value)
        } else if resetPulsed {
            // log("sampleAndHoldEval op: We had a pulse, returning value.defaultFalseValue: \(value.defaultFalseValue)")
            return PulseOpResultT(value.defaultFalseValue)
        } else {
            // log("sampleAndHoldEval op: returning prevValue: \(prevValue)")
            return PulseOpResultT(prevValue)
        }
    }
}

@MainActor
func sampleAndHoldEval(node: NodeViewModel,
                       graphStep: GraphStepState) -> ImpureEvalResult {

    let inputsValues = node.inputs
    let outputsValues: PortValuesList = node.outputs
    let graphTime: TimeInterval = graphStep.graphTime
    let nodeType = node.userVisibleType ?? .media
    
    let op = sampleAndHoldOpClosure(
        graphTime: graphTime,
        nodeType: nodeType)

    return pulseEvalUpdate(
        inputsValues,
        [outputsValues.first ?? [nodeType.defaultPortValue]],
        op)
}
