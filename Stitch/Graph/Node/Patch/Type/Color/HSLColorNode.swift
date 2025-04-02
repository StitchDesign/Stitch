//
//  HSLColorNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

let hueDefault = 0.5
let saturationDefault = 0.8
let lightnessDefault = 0.8

@MainActor
func hslColorNode(id: NodeId,
                  hue: Double = hueDefault,
                  saturation: Double = saturationDefault,
                  lightness: Double = lightnessDefault,
                  nodePosition: CGPoint = .zero,
                  nodeZIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            ("Hue", [.number(hue)]),
        ("Saturation", [.number(saturation)]),
        ("Lightness", [.number(lightness)]),
        ("Alpha", [.number(alphaDefault)]))

    let initialColor = Color(hue: hue,
                             saturation: saturation,
                             brightness: lightness)

    let outputs = toOutputs(id: id, offset: inputs.count,
                            values: (nil, [.color(initialColor)]))

    return PatchNode(
        position: nodePosition,
        zIndex: nodeZIndex,
        id: id,
        patchName: .hslColor,
        inputs: inputs,
        outputs: outputs)
}

@MainActor
func hslColorEval(inputs: PortValuesList,
                  outputs: PortValuesList) -> PortValuesList {
    let defaultOutputs: PortValues = [.color(Color(hue: hueDefault,
                                                   saturation: saturationDefault,
                                                   brightness: lightnessDefault))]

    let op: Operation = { (values: PortValues) -> PortValue in
        if let hue = values[0].getNumber,
           let saturation = values[safe: 1]?.getNumber,
           let lightness = values[safe: 2]?.getNumber,
           let alpha = values[safe: 3]?.getNumber {

            let hslColor = HSLColor(hue: hue,
                                    saturation: saturation,
                                    lightness: lightness,
                                    alpha: alpha)

            return .color(hslColor.toColor)

        } else {
            log("hslColorArray: reusing old color...")
            return values[safe: 4] ?? .color(Color.falseColor)
        }
    }

    return resultsMaker(inputs, outputs: [outputs.first ?? defaultOutputs
    ])(op)
}
