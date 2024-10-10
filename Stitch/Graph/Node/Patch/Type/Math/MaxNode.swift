//
//  MaxNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/16/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

@MainActor
func maxNode(id: NodeId,
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
            (nil, [.number([n, n2].max() ?? n)])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .max,
        inputs: inputs,
        outputs: outputs)
}

func maxEval(inputs: PortValuesList, outputs: PortValuesList) -> PortValuesList {
    //    log("maxEval called")

    let op: Operation = { (values: PortValues) -> PortValue in
        //        log("maxEval: values: \(values)")
        let n = values[0].getNumber ?? .zero
        let n2 = values[1].getNumber ?? .zero

        // ie if n == n2, then just use n
        let max: Double = [n, n2].max() ?? n

        return .number(max)
    }

    return resultsMaker(inputs)(op)
}
