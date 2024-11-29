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
                  position: CGSize = .zero,
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
        let position: Int = Int(values[safe: 1]?.getNumber ?? .zero)
        let length: Int = Int(values[safe: 2]?.getNumber ?? .zero)

        if position > (text.count - 1) {
            log("trimTextEval: position too far")
            return .string(.init(""))
        } else if length > text.count {
            log("trimTextEval: length too large for text")
            return .string(.init(text))
        } else {

            // if length is too far for the position-started string,
            // then return
            let newSub = text.substring(from: position)

            if length > newSub.count {
                log("trimTextEval: length too large for substring")
                let s = newSub[newSub.startIndex...newSub.endIndex]
                log("trimTextEval: length too large for substring: s: \(s)")
                return .string(.init(String(s)))
            }

            // the part of the string starting at position, to the end
            let endPosition = position + length
            let sub = text.substring(
                with: position..<endPosition)

            log("trimTextEval: position: \(position)")
            log("trimTextEval: endPosition: \(endPosition)")
            log("trimTextEval: sub: \(sub)")
            return .string(.init(sub))
        }
    }

    return resultsMaker(inputs)(op)
}
