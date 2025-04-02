//
//  ColorToHSLNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

@MainActor
func colorToHSLNode(id: NodeId,
                    hue: Double = hueDefault,
                    saturation: Double = saturationDefault,
                    lightness: Double = lightnessDefault,
                    position: CGPoint = .zero,
                    zIndex: Double = 0) -> PatchNode {

    let initialColor: Color = falseColor

    let inputs = toInputs(
        id: id,
        values: (nil, [.color(initialColor)]))

    let hsl = initialColor.toUIColor.hsl

    let outputs = toOutputs(
        id: id, offset: inputs.count,
        values: ("Hue", [.number(hsl.hue)]),
        ("Saturation", [.number(hsl.saturation)]),
        ("Lightness", [.number(hsl.lightness)]),
        ("Alpha", [.number(hsl.alpha)])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .colorToHSL,
        inputs: inputs,
        outputs: outputs)
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
