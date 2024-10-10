//
//  OptionSwitch.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/1/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// Like a combo of flipSwitch and optionPicker

// TODO: can these ports be extended? can a user add inputs?
struct OptionSwitchPatchNode: PatchNodeDefinition {
    static let patch = Patch.optionSwitch

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.pulse(0)],
                    label: "Set to 0"
                ),
                .init(
                    defaultValues: [.pulse(0)],
                    label: "Set to 1"
                ),
                .init(
                    defaultValues: [.pulse(0)],
                    label: "Set to 2"
                )
            ],
            outputs: [
                .init(
                    label: "Option",
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
func optionSwitchPatchNode(id: NodeId,
                           position: CGSize = .zero,
                           zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            ("Set to 0", [pulseDefaultFalse]),
        ("Set to 1", [pulseDefaultFalse]),
        ("Set to 2", [pulseDefaultFalse]))

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values: ("Option", [numberDefaultFalse]))

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .optionSwitch,
        inputs: inputs,
        outputs: outputs)
}

// the port number of the input that received the pulse becomes the new number in the output

func didPulse(value: PortValue, graphTime: TimeInterval) -> Bool {
    if let pulsedAt = value.getPulse {
        return pulsedAt.shouldPulse(graphTime)
    }
    return false
}

// TODO: if the inputs can be extended then we will need another way of handling this
func optionSwitchOpClosure(graphTime: TimeInterval) -> PulseOperationT {

    return { (values: PortValues) -> PulseOpResultT in

        // find the first input.valueAtIndex that pulsed...
        let firstPulsed: PortValue? = values.first(where: { (value: PortValue) -> Bool in
            didPulse(value: value, graphTime: graphTime)
        })

        if let pulsedValue = firstPulsed {
            log("optionSwitchEval: had pulse")
            // if we have a pulsedValue,
            // then return that value's index position
            // in values as the result
            //            log("optionSwitchEval: values.firstIndex(of: pulsedValue): \(values.firstIndex(of: pulsedValue))")

            let value = values.firstIndex(of: pulsedValue)!
            return PulseOpResultT(.number(Double(value)))
        } else {
            // no pulses at all on this index?
            log("optionSwitchEval: no pulse")
            return PulseOpResultT(values.last ?? numberDefaultFalse)
        }
    }
}

@MainActor
func optionSwitchEval(node: PatchNode,
                      graphStep: GraphStepState) -> ImpureEvalResult {

    let firstOutputValue = node.outputs.first ?? [.number(.zero)]

    let graphTime: TimeInterval = graphStep.graphTime

    let op = optionSwitchOpClosure(graphTime: graphTime)

    return pulseEvalUpdate(
        node.inputs,
        [firstOutputValue],
        op)
}
