//
//  LoopDedupeNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/2/22.
//

import Foundation
import StitchSchemaKit

// TODO: needs more node types ?
@MainActor
func loopDedupeNode(id: NodeId,
                    position: CGPoint = .zero,
                    zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            ("Loop", [numberDefaultFalse]) // 0
    )

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values:
            ("Loop", [numberDefaultFalse]),
        ("Index", [numberDefaultFalse])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .loopDedupe,
        userVisibleType: .number,
        inputs: inputs,
        outputs: outputs)
}

func loopDedupeEval(inputs: PortValuesList,
                    outputs: PortValuesList) -> PortValuesList {

    let input = inputs.first!
    let uniqueValues = input.unique

    return [
        uniqueValues,
        uniqueValues.asLoopIndices
    ]
}
