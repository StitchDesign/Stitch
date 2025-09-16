//
//  AnyPatchNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/2/22.
//

import Foundation
import StitchSchemaKit

struct AnyPatchNode: PatchNodeDefinition {
    static let patch = Patch.any
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        let effectiveType = type ?? .bool
        let defaultValue = effectiveType.defaultPortValue

        return .init(
            inputs: [
                .init(
                    defaultValues: [defaultValue],
                    label: "Loop"
                ),
                .init(
                    defaultValues: [.number(0)],
                    label: "Grouping"
                )
            ],
            outputs: [
                .init(
                    label: "",
                    type: .bool
                )
            ]
        )
    }
}


func anyEval(inputs: PortValuesList,
             outputs: PortValuesList) -> PortValuesList {

    // Most node evals operate 'one loop index at a time';
    // but many loop nodes' evals operate on the *entire* loop at once,
    // and output a single, non-loop value.
    let boolLoop: [Bool] = inputs.first!
        .compactMap(\.getBool)
        .filter(identity)

    if !boolLoop.isEmpty {
        return [[.bool(true)]]
    } else {
        return [[.bool(false)]]
    }
}
