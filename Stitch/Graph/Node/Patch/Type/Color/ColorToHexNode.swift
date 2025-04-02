//
//  ColorToHexNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import StitchSchemaKit

@MainActor
func colorToHexNode(id: NodeId,
                    position: CGPoint = .zero,
                    zIndex: Double = 0) -> PatchNode {

    let color = falseColor

    let inputs = toInputs(
        id: id,
        values: ("Color", [.color(color)]))

    let outputs = toOutputs(
        id: id, offset: inputs.count,
        values: ("Hex", [.string(.init(color.asHexDisplay))]))

    return PatchNode(position: position,
                     zIndex: zIndex,
                     id: id,
                     patchName: .colorToHex,
                     inputs: inputs,
                     outputs: outputs)
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
