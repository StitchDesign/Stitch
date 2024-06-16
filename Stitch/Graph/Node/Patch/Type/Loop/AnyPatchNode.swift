//
//  AnyPatchNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/2/22.
//

import Foundation
import StitchSchemaKit

@MainActor
func anyPatchNode(id: NodeId,
                  position: CGSize = .zero,
                  zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            ("Loop", [boolDefaultFalse]), // 0
        // TODO: use Grouping input properly
        ("Grouping", [.number(0)]) // 1
    )

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values:
            (nil, [boolDefaultFalse])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .any,
        inputs: inputs,
        outputs: outputs)
}

func anyEval(inputs: PortValuesList,
             outputs: PortValuesList) -> PortValuesList {

    // Most node evals operate 'one loop index at a time';
    // but many loop nodes' evals operate on the *entire* loop at once,
    // and output a single, non-loop value.
    let boolLoop: [Bool] = inputs.first!
        .compactMap(\.getBool)
        .filter(identity)

    if !boolLoop.isEmpty {
        return [[.bool(true)]]
    } else {
        return [[.bool(false)]]
    }
}
