//
//  SplitTextNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import StitchSchemaKit

@MainActor
func splitTextNode(id: NodeId,
                   position: CGSize = .zero,
                   zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values: ("Text", [.string(.init(""))]),
        ("Token", [.string(.init(""))])
    )

    let outputs = toOutputs(
        id: id, offset: inputs.count,
        values: (nil, [.string(.init(""))]))

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .splitText,
        inputs: inputs,
        outputs: outputs)
}

func splitTextEval(inputs: PortValuesList,
                   outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in
        let text: String = (values[safe: 0]?.getString?.string ?? .empty)
        let token: String = (values[safe: 1]?.getString?.string ?? .empty)

        if let first = text.split(separator: token).first {
            log("splitTextEval: first: \(first)")
            return .string(.init(String(first)))
        } else {
            return .string(.init(.empty))
        }
    }

    return resultsMaker(inputs)(op)
}
