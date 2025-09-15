//
//  TextLengthNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import StitchSchemaKit

struct TextLengthPatchNode: PatchNodeDefinition {
    static let patch = Patch.textLength
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.string(.init(""))],
                    label: "Text"
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

@MainActor
func textLengthNode(id: NodeId,
                    position: CGPoint = .zero,
                    zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values: ("Text", [.string(.init(""))]))

    let outputs = toOutputs(
        id: id, offset: inputs.count,
        values: (nil, [.number(.zero)]))

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .textLength,
        inputs: inputs,
        outputs: outputs)
}

@MainActor
func textLengthEval(inputs: PortValuesList,
                    outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in
        let textLength = (values[safe: 0]?.getString?.string ?? .empty).count
        return .number(Double(textLength))
    }

    return resultsMaker(inputs)(op)
}
