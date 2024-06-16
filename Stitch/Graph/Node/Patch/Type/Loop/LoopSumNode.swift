//
//  LoopSumNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/2/22.
//

import Foundation
import StitchSchemaKit

@MainActor
func loopSumNode(id: NodeId,
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
        // it's called index, but it's actually the loop that's coming out
        values:
            (nil, [.number(0)])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .loopSum,
        inputs: inputs,
        outputs: outputs)
}

// TODO: Origami docs indicate that this node can be number, index or bool type, but Origami in practice only has a single node type;
// ... and adding together a list of five bools is somehow "15", or some previously saved/used value?
func loopSumEval(inputs: PortValuesList,
                 outputs: PortValuesList) -> PortValuesList {
    let ns: [Double] = inputs.first!.map { $0.getNumber ?? .zero }
    return [
        [.number(ns.reduce(0.0, +))]
    ]
}
