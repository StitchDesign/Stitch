//
//  AndNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct AndPatchNode: PatchNodeDefinition {
    static let patch = Patch.and
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        let effectiveType = type ?? .bool
        let defaultValue = effectiveType.defaultPortValue

        return .init(
            inputs: [
                .init(
                    defaultValues: [defaultValue],
                    label: ""
                ),
                .init(
                    defaultValues: [defaultValue],
                    label: ""
                )
            ],
            outputs: [
                .init(
                    label: "",
                    type: .bool
                )
            ]
        )
    }
}

@MainActor
func andEval(inputs: PortValuesList,
             outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in
        let boolInputs: [Bool] = values.map { $0.getBool ?? false }
        #if DEBUG
        if boolInputs.isEmpty {
            fatalError("andEval")
        }
        #endif
        let opResult = boolInputs.allSatisfy(identity)
        return .bool(opResult)
    }

    return resultsMaker(inputs)(op)
}
