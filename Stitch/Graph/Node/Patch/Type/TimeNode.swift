//
//  TimeNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct TimePatchNode: PatchNodeDefinition {
    static let patch = Patch.time
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [],
            outputs: [
                .init(
                    label: "Time",
                    type: .number
                ),
                .init(
                    label: "Frame",
                    type: .number
                )
            ]
        )
    }
}

// Time is the only node that needs graphFrameCount from state;
@MainActor
func timeEvalWrapper(node: PatchNode,
                     state: GraphStepState) -> EvalResult {

    let inputsValues = node.inputs

    let outputs: PortValuesList = timeEval(
        inputsValues: inputsValues,
        graphFrames: state.graphFrameCount,
        graphTime: state.graphTime)

    return .init(outputsValues: outputs)
}

func timeEval(inputsValues: PortValuesList,
              graphFrames: Int,
              graphTime: TimeInterval) -> PortValuesList {

    // timeEval has no inputs, and so can never have a loop.
    let timeOutput: PortValues = [.number(graphTime)]
    let framesOutput: PortValues = [.number(Double(graphFrames))]

    return [timeOutput, framesOutput]
}

