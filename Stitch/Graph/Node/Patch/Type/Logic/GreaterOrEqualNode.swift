//
//  GreaterOrEqualNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct GreaterOrEqualPatchNode: PatchNodeDefinition {
    static let patch = Patch.greaterOrEqual
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(0)],
                    label: ""
                ),
                .init(
                    defaultValues: [.number(200)],
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

