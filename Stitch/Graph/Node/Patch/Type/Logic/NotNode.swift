//
//  NotNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/29/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct NotPatchNode: PatchNodeDefinition {
    static let patch = Patch.not
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.bool(false)],
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
func notEval(inputs: PortValuesList,
             outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in
        
        guard let value = values.first?.getBool else {
            fatalErrorIfDebug()
            return .bool(false)
        }
        
        return .bool(!value)
    }

    return resultsMaker(inputs)(op)
}
