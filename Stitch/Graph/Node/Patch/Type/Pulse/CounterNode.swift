//
//  CounterNode.swift
//  prototype
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI

struct CounterPatchNode: PatchNodeDefinition {
    static let patch = Patch.counter

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.pulse(0)],
                    label: "Increase"
                ),
                .init(
                    defaultValues: [.pulse(0)],
                    label: "Decrease"
                ),
                .init(
                    defaultValues: [.pulse(0)],
                    label: "Jump"
                ),
                .init(
                    defaultValues: [.number(0)],
                    label: "Jump to Number"
                ),
                .init(
                    defaultValues: [.number(0)],
                    label: "Maximum Count"
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
        ComputedNodeState()
    }
}

@MainActor
func counterEval(node: PatchNode,
                 graphStep: GraphStepState) -> ImpureEvalResult {

    let inputsValues = node.inputs
    let outputsValues = node.outputs
    let graphTime: TimeInterval = graphStep.graphTime

    let previousOutput: PortValues = outputsValues.first ?? [.number(.zero)]

    let op = counterOpClosure(graphTime: graphTime)

    return pulseEvalUpdate(
        inputsValues,
        [previousOutput],
        op)
}

func counterOpClosure(graphTime: TimeInterval) -> PulseOperationT {

    return { (values: PortValues) -> PulseOpResultT in

        let incPulsed = values[0].getPulse!.shouldPulse(graphTime)
        let decPulsed = values[1].getPulse!.shouldPulse(graphTime)
        let jumpPulsed = values[2].getPulse!.shouldPulse(graphTime)

        let jumpNumber = values[3].getNumber!
        let maxNumber = values[4].getNumber!

        // old output
        let prevValue: Double = values[safe: 5]?.getNumber ?? 0.0

        //        log("counterOpClosure: graphTime: \(graphTime)")
        //        log("counterOpClosure: incPulse: \(incPulse)")
        //        log("counterOpClosure: values[0].getPulse: \(values[0].getPulse!)")
        //        log("counterOpClosure: values[5].getNumber: \(values[5].getNumber!)")

        // Jump has priority if we received multiple pulses
        if jumpPulsed {
            return PulseOpResultT(.number(jumpNumber))
        }
        // Inc and Dec cancel each other out.
        else if incPulsed && decPulsed {
            //            log("counterOpClosure: no change")
            return PulseOpResultT(.number(prevValue))
        } else if incPulsed {
            //            log("counterOpClosure: incPulsed")
            var n = prevValue + 1
            if (maxNumber > 0) && n >= maxNumber {
                n = 0
            }
            return PulseOpResultT(.number(n))
        } else if decPulsed {
            //            log("counterOpClosure: decPulsed")
            return PulseOpResultT(.number(prevValue - 1))
        } else {
            //            log("counterOpClosure: no change")
            return PulseOpResultT(.number(prevValue))
        }
    }
}
