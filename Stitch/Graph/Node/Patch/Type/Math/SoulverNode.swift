//
//  SoulverNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 10/31/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import SoulverCore

// https://github.com/soulverteam/SoulverCore
func soulve(_ s: String) -> String {
    // TODO: make a top-level class?
    let calculator = Calculator(customization: .standard)
    return calculator.calculate(s).stringValue
}

@MainActor
func soulverNode(id: NodeId,
                 n1: String = "",
                 position: CGSize = .zero,
                 zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values: (nil, [.string(.init(n1.isEmpty ? "34% of 2k" : n1))])
    )

    let initialOutput = soulve(n1)

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values: (nil, [.string(.init(initialOutput))]))

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .soulver,
        inputs: inputs,
        outputs: outputs)
}

@MainActor
func soulverEval(inputs: PortValuesList,
                 outputs: PortValuesList) -> PortValuesList {

    let op = { @Sendable (values: PortValues) -> PortValue in
        let s = values.first?.getString?.string ?? ""
        let result = soulve(s)
        return .string(.init(result))
    }

    return resultsMaker(inputs)(op)
}
