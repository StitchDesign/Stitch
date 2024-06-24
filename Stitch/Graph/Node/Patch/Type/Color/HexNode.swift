//
//  HexNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

@MainActor
func hexNode(id: NodeId,
             position: CGSize = .zero,
             zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values: ("Hex", [.string(.init(""))]))

    let color: Color = UIColor(hex: Color.defaultFalseColorHex)?.toColor ?? falseColor

    let outputs = toOutputs(
        id: id, offset: inputs.count,
        values: ("Color", [.color(color)]))

    return PatchNode(position: position,
                     zIndex: zIndex,
                     id: id,
                     patchName: .hexColor,
                     inputs: inputs,
                     outputs: outputs)
}

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
