//
//  TimeNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// No node type or user-node types
// No inputs (i.e. inputs are disabled)
@MainActor
func timePatchNode(id: NodeId,
                   position: CGSize = .zero,
                   zIndex: Double = 0) -> PatchNode {

    let inputs = fakeInputs(id: id)

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values:
            ("Time", [numberDefaultFalse]),
        ("Frame", [numberDefaultFalse]))

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .time,
        inputs: inputs,
        outputs: outputs)
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
