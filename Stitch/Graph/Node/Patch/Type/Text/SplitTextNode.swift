//
//  SplitTextNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import StitchSchemaKit

struct SplitTextPatchNode: PatchNodeDefinition {
    static let patch = Patch.splitText
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        let effectiveType = type ?? .string
        let defaultValue = effectiveType.defaultPortValue

        return .init(
            inputs: [
                .init(
                    defaultValues: [defaultValue],
                    label: "Text"
                ),
                .init(
                    defaultValues: [defaultValue],
                    label: "Token"
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


@MainActor
func splitTextEval(inputs: PortValuesList,
                   outputs: PortValuesList) -> PortValuesList {

    // Note: if any input on this node has a loop, we only use the last index
    guard let text = inputs[safe: 0]?.last?.getString?.string, // last value in first input
          let token = inputs[safe: 1]?.last?.getString?.string // last value in second input
    else {
        return [[.string(.init(.empty))]]
    }
    
    let splitText: [String] = text.split(separator: token).map { String($0) }
    
    guard !splitText.isEmpty else {
        return [[PortValue.string(.init(""))]]
    }
    
    return [
        splitText.map { PortValue.string(.init($0))}
    ]
}
