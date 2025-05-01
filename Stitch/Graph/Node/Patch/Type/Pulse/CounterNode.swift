//
//  CounterNode.swift
//  Stitch
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
    
    let graphTime: TimeInterval = graphStep.graphTime
    
    return node.loopedEvalOutputsPersistence(graphTime: graphTime) { values, computedState in
        counterOpClosure(values: values,
                         graphTime: graphTime,
                         computedState: computedState)
    }
}

func counterOpClosure(values: PortValues,
                      graphTime: TimeInterval,
                      computedState: ComputedNodeState) -> PortValue {
    let incPulsed = values[0].getPulse?.shouldPulse(graphTime) ?? false
    let decPulsed = values[1].getPulse?.shouldPulse(graphTime) ?? false
    let jumpPulsed = values[2].getPulse?.shouldPulse(graphTime) ?? false
    
    let jumpNumber = values[3].getNumber ?? .zero
    let maxNumber = values[4].getNumber ?? .zero
    
    // old output
    let prevValue: Double = computedState.previousValue?.getNumber ?? .zero
    
    //        log("counterOpClosure: graphTime: \(graphTime)")
    //        log("counterOpClosure: incPulse: \(incPulse)")
    //        log("counterOpClosure: values[0].getPulse: \(values[0].getPulse!)")
    //        log("counterOpClosure: values[5].getNumber: \(values[5].getNumber!)")
    
    // Jump has priority if we received multiple pulses
    if jumpPulsed {
        return .number(jumpNumber)
    }
    // Inc and Dec cancel each other out.
    else if incPulsed && decPulsed {
        //            log("counterOpClosure: no change")
        return .number(prevValue)
    } else if incPulsed {
        //            log("counterOpClosure: incPulsed")
        var n = prevValue + 1
        if (maxNumber > 0) && n >= maxNumber {
            n = 0
        }
        return .number(n)
    } else if decPulsed {
        //            log("counterOpClosure: decPulsed")
        return .number(prevValue - 1)
    } else {
        //            log("counterOpClosure: no change")
        return .number(prevValue)
    }
}
