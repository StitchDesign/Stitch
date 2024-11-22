//
//  AbsoluteValueNode.swift
//  prototype
//
//  Created by Christian J Clampitt on 8/25/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

@MainActor
func absoluteValueNode(id: NodeId,
                       n: Double = 1,
                       position: CGSize = .zero,
                       zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            (nil, [.number(n)])
    )

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values:
            (nil, [.number(abs(n))])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .absoluteValue,
        inputs: inputs,
        outputs: outputs)
}

func absoluteValueEval(inputs: PortValuesList, outputs: PortValuesList) -> PortValuesList {
    log("absoluteValueEval called")

    let op: Operation = { (values: PortValues) -> PortValue in
        log("absoluteValueEval: values: \(values)")
        let n = values[0].getNumber!

        // ie if n == n2, then just use n
        let absoluteValue: Double = abs(n)

        return .number(absoluteValue)
    }

    return resultsMaker(inputs)(op)
}
