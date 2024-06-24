//
//  TextEndsWithNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import StitchSchemaKit

@MainActor
func textEndsWithNode(id: NodeId,
                      position: CGSize = .zero,
                      zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values: ("Text", [.string(.init(""))]),
        ("Suffix", [.string(.init(""))])
    )

    let outputs = toOutputs(
        id: id, offset: inputs.count,
        values: (nil, [.bool(false)]))

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .textEndsWith,
        inputs: inputs,
        outputs: outputs)
}

func textEndsWithEval(inputs: PortValuesList,
                      outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in
        let text: String = (values[safe: 0]?.getString?.string ?? .empty)
        let suffix: String = (values[safe: 1]?.getString?.string ?? .empty)
        return .bool(text.hasSuffix(suffix))
    }

    return resultsMaker(inputs)(op)
}
