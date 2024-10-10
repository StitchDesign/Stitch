//
//  PulseOnChangeNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/1/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct PulseOnChangeNode: PatchNodeDefinition {
    static let patch = Patch.pulseOnChange

    static let defaultUserVisibleType: UserVisibleType? = .number

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(0)],
                    label: "Value"
                )
            ],
            outputs: [
                .init(
                    label: "",
                    type: .pulse
                )
            ]
        )
    }

    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        let prevValue: PortValue = .number(0)
        return ComputedNodeState(
            previousValue: prevValue)
    }
}

// outPulse is for an Output; can never be manually pulsed.
func pulseOnChangeOpClosure(values: PortValues,
                            computedState: ComputedNodeState,
                            graphTime: TimeInterval) -> ImpureEvalOpResult {
    let newVal: PortValue = values[safe: 0] ?? numberDefaultFalse
    let oldPulse: PortValue = values[safe: 1] ?? pulseDefaultFalse // assumes was pulse
    let prevVal: PortValue = computedState.previousValue ?? numberDefaultFalse
    let changed = newVal != prevVal
    
    // update prev values
    computedState.previousValue = newVal
    
    var jsonChange = false
    if let json1 = newVal.getStitchJSON,
       let json2 = prevVal.getStitchJSON {
        jsonChange = json1.id != json2.id
    }
    
    let _changed = jsonChange || changed
    
    //        if newVal != prevVal {
    if _changed {
        return ImpureEvalOpResult(.pulse(graphTime)
        )
    } else {
        return ImpureEvalOpResult(oldPulse)
    }
}

@MainActor
func pulseOnChangeEval(node: PatchNode,
                       // only needs graphTime
                       state: GraphStepState) -> ImpureEvalResult {
    
    // Update computed node state
    node.loopedEval(ComputedNodeState.self) { values, computedState, _ in
        pulseOnChangeOpClosure(values: values,
                               computedState: computedState,
                               graphTime: state.graphTime)
    }
    .toImpureEvalResult() //defaultOutputs: [[numberDefaultFalse]])
}
