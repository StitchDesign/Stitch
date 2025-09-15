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

struct SoulverPatchNode: PatchNodeDefinition {
    static let patch = Patch.soulver
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.string(.init("34% of 2k"))],
                    label: ""
                )
            ],
            outputs: [
                .init(
                    label: "",
                    type: .string
                )
            ]
        )
    }
}

// https://github.com/soulverteam/SoulverCore
func soulve(_ s: String) -> String {
    // TODO: make a top-level class?
    let calculator = Calculator(customization: .standard)
    return calculator.calculate(s).stringValue
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
