//
//  TextTransformNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import StitchSchemaKit

extension TextTransform: PortValueEnum {
    static let defaultTransform: Self = .uppercase

    static var portValueTypeGetter: PortValueTypeGetter<Self> {
        PortValue.textTransform
    }

    var display: String {
        switch self {
        case .uppercase:
            return "Uppercase"
        case .lowercase:
            return "Lowercase"
        case .capitalize:
            return "Capitalize"
        }
    }
}

struct TextTransformPatchNode: PatchNodeDefinition {
    static let patch = Patch.textTransform
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.string(.init(""))],
                    label: "Text"
                ),
                .init(
                    defaultValues: [.textTransform(.defaultTransform)],
                    label: "Transform"
                )
            ],
            outputs: [
                .init(
                    label: "",
                    type: .string
                )
            ]
        )
    }
}


@MainActor
func textTransformEval(inputs: PortValuesList,
                       outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in
        let text: String = (values.first?.getString?.string ?? .empty)
        let transform: TextTransform = (values[safe: 1]?.getTextTransform ?? .defaultTransform)

        switch transform {
        case .uppercase:
            return .string(.init(text.uppercased()))
        case .lowercase:
            return .string(.init(text.lowercased()))
        case .capitalize:
            return .string(.init(text.capitalized))
        }
    }

    return resultsMaker(inputs)(op)
}
