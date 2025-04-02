//
//  ColorToRGBANode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

@MainActor
func colorToRGBANode(id: NodeId,
                     hue: Double = hueDefault,
                     saturation: Double = saturationDefault,
                     lightness: Double = lightnessDefault,
                     position: CGPoint = .zero,
                     zIndex: Double = 0) -> PatchNode {

    let initialColor: Color = falseColor

    let inputs = toInputs(
        id: id,
        values: (nil, [.color(initialColor)]))

    let rgba = initialColor.asRGBA

    let outputs = toOutputs(
        id: id, offset: inputs.count,
        values: ("Red", [.number(rgba.red)]),
        ("Green", [.number(rgba.green)]),
        ("Blue", [.number(rgba.blue)]),
        ("Alpha", [.number(rgba.alpha)])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .colorToRGB,
        inputs: inputs,
        outputs: outputs)
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
