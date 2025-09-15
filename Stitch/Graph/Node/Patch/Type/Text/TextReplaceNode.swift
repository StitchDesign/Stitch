//
//  TextReplaceNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import StitchSchemaKit

struct TextReplacePatchNode: PatchNodeDefinition {
    static let patch = Patch.textReplace
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
                    label: "Find"
                ),
                .init(
                    defaultValues: [.string(.init(""))],
                    label: "Replace"
                ),
                .init(
                    defaultValues: [.bool(false)],
                    label: "Case Sensitive"
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
func textReplaceNode(id: NodeId,
                     position: CGPoint = .zero,
                     zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values: ("Text", [.string(.init(""))]),
        ("Find", [.string(.init(""))]),
        ("Replace", [.string(.init(""))]),
        ("Case Sensitive", [.bool(false)])
    )

    let outputs = toOutputs(
        id: id, offset: inputs.count,
        values: (nil, [.string(.init(""))]))

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .textReplace,
        inputs: inputs,
        outputs: outputs)
}

// What's the proper case-sensitive logic?
//
@MainActor
func textReplaceEval(inputs: PortValuesList,
                     outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in
        let text: String = values[safe: 0]?.getString?.string ?? .empty
        let find: String = values[safe: 1]?.getString?.string ?? .empty
        let replace: String = values[safe: 2]?.getString?.string ?? .empty
        let isCaseSensitive: Bool = values[safe: 3]?.getBool ?? false

        // For text = "Love" and find = "Ove", we won't find anything.
        let result = text.replacingOccurrences(
            of: find,
            with: replace,
            options: !isCaseSensitive ? [.caseInsensitive] : [])

        // log("textReplaceEval: result: \(result)")

        return .string(.init(result))
    }

    return resultsMaker(inputs)(op)
}
