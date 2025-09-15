//
//  RGBANode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/5/22.
//

import SwiftUI
import StitchSchemaKit

struct RGBAPatchNode: PatchNodeDefinition {
    static let patch = Patch.rgba
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(redDefault)],
                    label: "Red"
                ),
                .init(
                    defaultValues: [.number(greenDefault)],
                    label: "Green"
                ),
                .init(
                    defaultValues: [.number(blueDefault)],
                    label: "Blue"
                ),
                .init(
                    defaultValues: [.number(alphaDefault)],
                    label: "Alpha"
                )
            ],
            outputs: [
                .init(
                    label: "",
                    type: .color
                )
            ]
        )
    }
}

let RGBA_COLOR_DISPLAY_TITLE = "RGB Color"

let redDefault: Double = 0
let greenDefault: Double = 0
let blueDefault: Double = 0
let alphaDefault: Double = 1.0


@MainActor
func rgbaEval(inputs: PortValuesList,
              outputs: PortValuesList) -> PortValuesList {
    let defaultOutputs: PortValues = [.color(Color(red: redDefault,
                                                   green: greenDefault,
                                                   blue: blueDefault,
                                                   alpha: alphaDefault))]

    let op: Operation = { (values: PortValues) -> PortValue in
        if let red = values[safe: 0]?.getNumber,
           let green = values[safe: 1]?.getNumber,
           let blue = values[safe: 2]?.getNumber,
           let alpha = values[safe: 3]?.getNumber {

            return .color(RGBA(red: red,
                               green: green,
                               blue: blue,
                               alpha: alpha).toColor)
        } else {
            log("rgbaEval: reusing old color...")
            return values[4]
        }
    }

    return resultsMaker(inputs, outputs: [outputs.first ?? defaultOutputs])(op)
}
