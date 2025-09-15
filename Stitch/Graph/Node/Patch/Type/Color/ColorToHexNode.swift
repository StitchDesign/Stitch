//
//  ColorToHexNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import StitchSchemaKit

struct ColorToHexPatchNode: PatchNodeDefinition {
    static let patch = Patch.colorToHex
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.color(falseColor)],
                    label: "Color"
                )
            ],
            outputs: [
                .init(
                    label: "Hex",
                    type: .string
                )
            ]
        )
    }
}


@MainActor
func colorToHexEval(inputs: PortValuesList,
                    outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in
        let color = values[0].getColor ?? falseColor
        return .string(.init(color.asHexDisplay))
    }

    return resultsMaker(inputs)(op)
}
