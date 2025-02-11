//
//  LoopReverseNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/2/22.
//

import Foundation
import StitchSchemaKit

@MainActor
func loopReverseNode(id: NodeId,
                     position: CGSize = .zero,
                     zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            ("Loop", [.number(0)]) // 0
    )

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values:
            (nil, [.number(0)])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .loopReverse,
        userVisibleType: .number,
        inputs: inputs,
        outputs: outputs)
}

func loopReverseEval(inputs: PortValuesList,
                     outputs: PortValuesList) -> PortValuesList {
    let inputLoop: PortValues = inputs.first!
    return [inputLoop.reversed()]
}
