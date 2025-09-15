//
//  LoopNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct LoopStartPatchNode: PatchNodeDefinition {
    static let patch = Patch.loop
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(3)],
                    label: "Count"
                )
            ],
            outputs: [
                .init(
                    label: "Index",
                    type: .number
                )
            ]
        )
    }
}

func loopStartEval(inputs: PortValuesList,
                   outputs: PortValuesList) -> PortValuesList {

    // Origami loopStart node turns an input loops into nil outputs.
    // We default to taking the first value from an input loop,
    // and using that as count.
    assertInDebug(inputs.first?.first?.getNumber.isDefined ?? false)
    
    let number: Double = inputs.first?.first?.getNumber ?? .zero
    
    let nodeCount = Int(number)
    
    // We can't have a loop of length less than 1
    if nodeCount < 1 {
        let indicesLoop: PortValues = [.number(0)]
        return [indicesLoop]
    }
    
    let indicesLoop: PortValues = (0..<Int(nodeCount)).map { .number(Double($0))}
    return [indicesLoop]
}
