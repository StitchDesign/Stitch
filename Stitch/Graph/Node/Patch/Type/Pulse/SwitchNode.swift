//
//  SwitchNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct SwitchNode: PatchNodeDefinition {
    static let patch = Patch.flipSwitch

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.pulse(0)],
                    label: "Flip"
                ),
                .init(
                    defaultValues: [.pulse(0)],
                    label: "Turn On"
                ),
                .init(
                    defaultValues: [.pulse(0)],
                    label: "Turn Off"
                )
            ],
            outputs: [
                .init(
                    label: "On/Off",
                    type: .bool
                )
            ]
        )
    }

    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        ComputedNodeState()
    }
}

@MainActor
func switchEval(node: PatchNode,
                graphStep: GraphStepState) -> ImpureEvalResult {
    node.loopedEvalOutputsPersistence(graphTime: graphStep.graphTime) { values, computedState in
        switchOpClosure(values: values,
                        graphTime: graphStep.graphTime,
                        computedState: computedState)
    }
}

@MainActor
func switchOpClosure(values: PortValues,
                     graphTime: TimeInterval,
                     computedState: ComputedNodeState) -> PortValue {

    // values are all the inputs' values at that given index slot
    let flipPulsed: Bool = (values.first?.getPulse ?? .zero).shouldPulse(graphTime)
    
    let onPulsed: Bool = (values[safe: 1]?.getPulse ?? .zero).shouldPulse(graphTime)
    
    let offPulsed: Bool = (values[safe: 2]?.getPulse ?? .zero).shouldPulse(graphTime)
    
    //        log("switchEval op: flipPulsed: \(flipPulsed)")
    //        log("switchEval op: onPulsed: \(onPulsed)")
    //        log("switchEval op: flipPulsed: \(flipPulsed)")
    
    // previous outputs were added to end of inputs
    let prevValue: PortValue = computedState.previousValue ?? .bool(false)
    
    if prevValue.getBool == nil {
        fatalError("switchEval")
    }
    
    // NEEDS TESTS; only confirmed in-app.
    
    // ie turn on + turn off at same time => noop
    // and shouldFlip overpowers should turn on vs off
    if flipPulsed {
        let x = toggleBool(prevValue.getBool!)
        //            log("switchEval op: flip: x: \(x)")
        return .bool(x)
    } else if onPulsed && !offPulsed {
        return .bool(true)
    } else if !onPulsed && offPulsed {
        return .bool(false)
    } else {
        //            log("switchEval op: default: prevValue: \(prevValue)")
        return prevValue
    }
}
