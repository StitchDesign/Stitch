//
//  LoopDedupeNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/2/22.
//

import Foundation
import StitchSchemaKit

struct LoopDedupePatchNode: PatchNodeDefinition {
    static let patch = Patch.loopDedupe
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
                    label: "Loop",
                    type: type ?? .number
                ),
                .init(
                    label: "Index",
                    type: .number
                )
            ]
        )
    }
}

func loopDedupeEval(inputs: PortValuesList,
                    outputs: PortValuesList) -> PortValuesList {

    let input = inputs.first!
    let uniqueValues = input.unique

    return [
        uniqueValues,
        uniqueValues.asLoopIndices
    ]
}
