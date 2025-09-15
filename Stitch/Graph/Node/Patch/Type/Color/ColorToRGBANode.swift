//
//  ColorToRGBANode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct ColorToRGBAPatchNode: PatchNodeDefinition {
    static let patch = Patch.colorToRGB
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
                    label: "Red",
                    type: .number
                ),
                .init(
                    label: "Green",
                    type: .number
                ),
                .init(
                    label: "Blue",
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
func colorToRGBAEval(inputs: PortValuesList,
                     outputs: PortValuesList) -> PortValuesList {

    let op: Operation4 = { (values: PortValues) -> (PortValue, PortValue, PortValue, PortValue) in

        let color: Color = values[0].getColor ?? .empty
        let rgba = color.asRGBA

        return (
            .number(rgba.red),
            .number(rgba.green),
            .number(rgba.blue),
            .number(rgba.alpha)
        )
    }

    return resultsMaker4(inputs)(op)
}
