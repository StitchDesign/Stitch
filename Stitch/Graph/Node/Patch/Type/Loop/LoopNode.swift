//
//  LoopNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

@MainActor
func loopStartNode(id: NodeId,
                   loopCount: Double = 3,
                   position: CGSize = .zero,
                   zIndex: Double = 0) -> PatchNode {

    let indicesLoop: PortValues = (0..<Int(loopCount)).map { .number(Double($0))}

    let inputs = toInputs(id: id, values: ("Count", [.number(loopCount)]))

    let outputs = toOutputs(id: id,
                            offset: inputs.count,
                            values: ("Index", indicesLoop))

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .loop,
        inputs: inputs,
        outputs: outputs)
}

func loopStartEval(inputs: PortValuesList,
                   outputs: PortValuesList) -> PortValuesList {

    // Origami loopStart node turns an input loops into nil outputs.
    // We default to taking the first value from an input loop,
    // and using that as count.
    if let number: Double = inputs.first!.first!.getNumber {

        let nodeCount = Int(number)

        // We can't have a loop of length less than 1
        if nodeCount < 1 {
            let indicesLoop: PortValues = [.number(0)]
            return [indicesLoop]
        }

        let indicesLoop: PortValues = (0..<Int(nodeCount)).map { .number(Double($0))}
        return [indicesLoop]
    } else {
        log("loopStartEval: did not have node count")
        fatalError("loopStartEval")
    }
}
