//
//  MinNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import StitchSchemaKit

@MainActor
func minNode(id: NodeId,
             n: Double = 1,
             n2: Double = 0,
             position: CGSize = .zero,
             zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            (nil, [.number(n)]),
        (nil, [.number(n2)])
    )

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values:
            (nil, [.number([n, n2].min() ?? n)])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .min,
        inputs: inputs,
        outputs: outputs)
}

@MainActor
func minEval(inputs: PortValuesList, outputs: PortValuesList) -> PortValuesList {
    // log("minEval called")

    let op: Operation = { (values: PortValues) -> PortValue in
        // log("minEval: values: \(values)")
        let n = values[0].getNumber ?? .zero
        let n2 = values[1].getNumber ?? .zero

        // ie if n == n2, then just use n
        let min: Double = [n, n2].min() ?? n

        return .number(min)
    }

    return resultsMaker(inputs)(op)
}
