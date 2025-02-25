//
//  SplitterPatchNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import SwiftyJSON

//        let min = 188.0 // not enough
//        let min = 192.0 // too much ?
let SPLITTER_NODE_MINIMUM_WIDTH: CGFloat = 190

// Starts out as a number?
struct SplitterPatchNode: PatchNodeDefinition {
    static let patch = Patch.splitter

    static let defaultUserVisibleType: UserVisibleType? = .number

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(0)],
                    label: ""
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

@MainActor
func splitterEval(node: PatchNode,
                  graphStep: GraphStepState) -> EvalResult {

    let inputsValues = node.inputs

    // splitter must have node-type
    if let nodeType = node.userVisibleType,
       nodeType == .pulse {
        //        log("splitterEval: had pulse node type")
        let op = splitterPulseOpclosure(
            graphTime: graphStep.graphTime)
        return pulseEvalUpdate(inputsValues,
                               [],
                               op)
    } else {
        //        log("splitterEval: had other node type")
        let eval = outputsOnlyEval(identityEvaluation)
        let result = eval(node)
        return ImpureEvalResult(outputsValues: result.outputsValues)
    }

}

func splitterPulseOpclosure(graphTime: TimeInterval) -> PulseOperationT {

    return { (values: PortValues) -> PulseOpResultT in

        // splitter node only ever has one input
        let value: PortValue = values[0]
        let pulsed = (value.getPulse ?? .zero).shouldPulse(graphTime)

        if pulsed {
            //            log("splitterPulseOpclosure: returning pulse")
            return PulseOpResultT(
                //                value,
                .pulse(graphTime)) // had a pulse, so return .pulse(graphTime) h
        } else {
            //            log("splitterPulseOpclosure: not returning pulse")
            return PulseOpResultT(value)
        }
    }
}
