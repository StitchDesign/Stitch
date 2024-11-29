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

@MainActor
func textTransformNode(id: NodeId,
                       position: CGSize = .zero,
                       zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values: ("Text", [.string(.init(""))]),
        ("Transform", [.textTransform(.defaultTransform)])
    )

    let outputs = toOutputs(
        id: id, offset: inputs.count,
        values: (nil, [.bool(false)]))

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .textTransform,
        inputs: inputs,
        outputs: outputs)
}

@MainActor
func textTransformEval(inputs: PortValuesList,
                       outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in
        let text: String = (values[safe: 0]?.getString?.string ?? .empty)
        let transform: TextTransform = (values[1].getTextTransform ?? .defaultTransform)

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
