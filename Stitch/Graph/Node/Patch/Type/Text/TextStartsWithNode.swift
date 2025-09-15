//
//  TextStartsWithNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import StitchSchemaKit

struct TextStartsWithPatchNode: PatchNodeDefinition {
    static let patch = Patch.textStartsWith
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
                    label: "Prefix"
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
func textStartsWithEval(inputs: PortValuesList,
                        outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in
        let text: String = (values[safe: 0]?.getString?.string ?? .empty)
        let prefix: String = (values[safe: 1]?.getString?.string ?? .empty)
        return .bool(text.hasPrefix(prefix))
    }

    return resultsMaker(inputs)(op)
}
