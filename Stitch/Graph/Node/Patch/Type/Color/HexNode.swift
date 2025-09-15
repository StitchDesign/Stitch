//
//  HexNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct HexPatchNode: PatchNodeDefinition {
    static let patch = Patch.hexColor
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.string(.init(falseColor.asHexDisplay))],
                    label: "Hex"
                )
            ],
            outputs: [
                .init(
                    label: "Color",
                    type: .color
                )
            ]
        )
    }
}

@MainActor
func hexNode(id: NodeId,
             position: CGPoint = .zero,
             zIndex: Double = 0) -> PatchNode {

    let defaultColor = falseColor
    let hexStringForDefaultColor = defaultColor.asHexDisplay
    
    let inputs = toInputs(
        id: id,
        values: ("Hex", [.string(.init(hexStringForDefaultColor))]))

    let outputs = toOutputs(
        id: id, offset: inputs.count,
        values: ("Color", [.color(defaultColor)]))

    return PatchNode(position: position,
                     zIndex: zIndex,
                     id: id,
                     patchName: .hexColor,
                     inputs: inputs,
                     outputs: outputs)
}

@MainActor
func hexEval(inputs: PortValuesList,
             outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in

        if let hex = values[0].getString?.string {
            let color = UIColor(hex: hex)?.toColor ?? falseColor
            return .color(color)
        } else {
            log("HexEval: could not convert hex to color...")
            return .color(.white)
        }
    }

    return resultsMaker(inputs)(op)
}
