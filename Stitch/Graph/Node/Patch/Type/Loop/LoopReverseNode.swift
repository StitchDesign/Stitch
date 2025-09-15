//
//  LoopReverseNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/2/22.
//

import Foundation
import StitchSchemaKit

struct LoopReversePatchNode: PatchNodeDefinition {
    static let patch = Patch.loopReverse
    static let defaultUserVisibleType: UserVisibleType? = .number

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
                    type: type ?? .number
                )
            ]
        )
    }
}

func loopReverseEval(inputs: PortValuesList,
                     outputs: PortValuesList) -> PortValuesList {
    let inputLoop: PortValues = inputs.first!
    return [inputLoop.reversed()]
}
