//
//  EqualsExactlyExactly.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct EqualsExactlyPatchNode: PatchNodeDefinition {
    static let patch = Patch.equalsExactly
    static let defaultUserVisibleType: UserVisibleType? = .number

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        let effectiveType = type ?? .number
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
func equalsExactlyEval(inputs: PortValuesList,
                       outputs: PortValuesList) -> PortValuesList {
    
    let op: Operation = { (values: PortValues) -> PortValue in
        guard let firstValue = values.first else {
            return .bool(false)
        }
        
        // All values must be exactly the same as each other (fine to check against first value),
        // otherwise we return false.
        return .bool(values.allSatisfy({ $0 == firstValue }))
    }
    
    return resultsMaker(inputs)(op)
}
