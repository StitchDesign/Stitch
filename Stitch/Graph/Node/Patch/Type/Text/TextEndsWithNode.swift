//
//  TextEndsWithNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import StitchSchemaKit

struct TextEndsWithPatchNode: PatchNodeDefinition {
    static let patch = Patch.textEndsWith
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.string(.init(""))],
                    label: "Text"
                ),
                .init(
                    defaultValues: [.string(.init(""))],
                    label: "Suffix"
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


@MainActor
func textEndsWithEval(inputs: PortValuesList,
                      outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in
        let text: String = (values[safe: 0]?.getString?.string ?? .empty)
        let suffix: String = (values[safe: 1]?.getString?.string ?? .empty)
        return .bool(text.hasSuffix(suffix))
    }

    return resultsMaker(inputs)(op)
}
