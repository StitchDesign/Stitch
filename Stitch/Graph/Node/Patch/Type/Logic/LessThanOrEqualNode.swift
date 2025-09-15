//
//  LessThanOrEqualNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/7/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct LessThanOrEqualPatchNode: PatchNodeDefinition {
    static let patch = Patch.lessThanOrEqual
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

