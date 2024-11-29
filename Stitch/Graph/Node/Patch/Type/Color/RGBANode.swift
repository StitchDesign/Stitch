//
//  RGBANode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/5/22.
//

import SwiftUI
import StitchSchemaKit

let RGBA_COLOR_DISPLAY_TITLE = "RGB Color"

let redDefault: Double = 0
let greenDefault: Double = 0
let blueDefault: Double = 0
let alphaDefault: Double = 1.0

@MainActor
func rgbaNode(id: NodeId,
              red: Double = redDefault,
              green: Double = greenDefault,
              blue: Double = blueDefault,
              alpha: Double = alphaDefault,
              position: CGSize = .zero,
              zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            ("Red", [.number(red)]),
        ("Green", [.number(green)]),
        ("Blue", [.number(blue)]),
        ("Alpha", [.number(alpha)]))

    let initialColor: Color = RGBA(red: red,
                                   green: green,
                                   blue: blue,
                                   alpha: alpha).toColor

    let outputs = toOutputs(id: id, offset: inputs.count,
                            values: (nil, [.color(initialColor)]))

    return PatchNode(position: position,
                     zIndex: zIndex,
                     id: id,
                     patchName: .rgba,
                     inputs: inputs,
                     outputs: outputs)
}

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
