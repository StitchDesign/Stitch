//
//  GreaterThanNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct GreaterThanPatchNode: PatchNodeDefinition {
    static let patch = Patch.greaterThan
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(0)],
                    label: ""
                ),
                .init(
                    defaultValues: [.number(0)],
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

