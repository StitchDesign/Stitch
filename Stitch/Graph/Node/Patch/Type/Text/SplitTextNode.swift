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

@MainActor
func splitTextEval(inputs: PortValuesList,
                   outputs: PortValuesList) -> PortValuesList {

    // Note: if any input on this node has a loop, we only use the last index
    guard let text = inputs[safe: 0]?.last?.getString?.string, // last value in first input
          let token = inputs[safe: 1]?.last?.getString?.string // last value in second input
    else {
        return [[.string(.init(.empty))]]
    }
    
    let splitText: [String] = text.split(separator: token).map { String($0) }
    return [
        splitText.map { PortValue.string(.init($0))}
    ]
}
