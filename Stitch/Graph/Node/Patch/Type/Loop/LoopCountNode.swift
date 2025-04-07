//
//  loopCountNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/2/22.
//

import Foundation
import StitchSchemaKit

@MainActor
func loopCountNode(id: NodeId,
                   position: CGPoint = .zero,
                   zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            ("Loop", [.number(0)]) // 0
    )

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values:
            (nil, [.number(1)])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .loopCount,
        inputs: inputs,
        outputs: outputs)
}

func loopCountEval(inputs: PortValuesList,
                   outputs: PortValuesList) -> PortValuesList {
    guard let input = inputs.first else {
        fatalErrorIfDebug()
        return inputs
    }
    
    return [[.number(Double(input.count))]]
}
