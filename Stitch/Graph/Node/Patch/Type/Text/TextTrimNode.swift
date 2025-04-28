//
//  TextTrimNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import StitchSchemaKit

@MainActor
func trimTextNode(id: NodeId,
                  position: CGPoint = .zero,
                  zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values: ("Text", [.string(.init(""))]),
        ("Position", [numberDefaultFalse]),
        ("Length", [numberDefaultFalse])
    )

    let outputs = toOutputs(
        id: id, offset: inputs.count,
        values: (nil, [.string(.init(.empty))]))

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .trimText,
        inputs: inputs,
        outputs: outputs)
}

// https://origami.design/documentation/patches/builtin.textsubstring
// https://stackoverflow.com/questions/39677330/how-does-string-substring-work-in-swift
@MainActor
func trimTextEval(inputs: PortValuesList,
                  outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in
        let text: String = values[safe: 0]?.getString?.string ?? .empty
        var position: Int = Int(values[safe: 1]?.getNumber ?? .zero)
        let length: Int = Int(values[safe: 2]?.getNumber ?? .zero)
        
        if position > (text.count - 1) {
            return .string(.init(""))
        } else {
            // Treat negative position as 0th index
            if position < 0 {
                position = 0
            }
            
            let newSub = text
                .substring(from: position)
                .prefix(length)
            
            return .string(StitchStringValue(String(newSub)))
        }
    }

    return resultsMaker(inputs)(op)
}
