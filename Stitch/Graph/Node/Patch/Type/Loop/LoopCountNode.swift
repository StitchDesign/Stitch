//
//  loopCountNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/2/22.
//

import Foundation
import StitchSchemaKit

struct LoopCountPatchNode: PatchNodeDefinition {
    static let patch = Patch.loopCount
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(0)],
                    label: "Loop"
                )
            ],
            outputs: [
                .init(
                    label: "",
                    type: .number
                )
            ]
        )
    }
}

func loopCountEval(inputs: PortValuesList,
                   outputs: PortValuesList) -> PortValuesList {
    guard let input = inputs.first else {
        fatalErrorIfDebug()
        return inputs
    }
    
    return [[.number(Double(input.count))]]
}
