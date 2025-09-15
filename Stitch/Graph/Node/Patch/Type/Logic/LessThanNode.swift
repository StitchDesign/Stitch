//
//  LessThanNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct LessThanPatchNode: PatchNodeDefinition {
    static let patch = Patch.lessThan
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

