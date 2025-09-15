//
//  ColorToHSLNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct ColorToHSLPatchNode: PatchNodeDefinition {
    static let patch = Patch.colorToHSL
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.color(falseColor)],
                    label: ""
                )
            ],
            outputs: [
                .init(
                    label: "Hue",
                    type: .number
                ),
                .init(
                    label: "Saturation",
                    type: .number
                ),
                .init(
                    label: "Lightness",
                    type: .number
                ),
                .init(
                    label: "Alpha",
                    type: .number
                )
            ]
        )
    }
}


@MainActor
func colorToHSLEval(inputs: PortValuesList, outputs: PortValuesList) -> PortValuesList {

    let op: Operation4 = { (values: PortValues) -> (PortValue, PortValue, PortValue, PortValue) in

        let color = values[0].getColor ?? .empty
        let hsl = color.toUIColor.hsl

        return (
            .number(hsl.hue),
            .number(hsl.saturation),
            .number(hsl.lightness),
            .number(hsl.alpha)
        )
    }

    return resultsMaker4(inputs)(op)
}
