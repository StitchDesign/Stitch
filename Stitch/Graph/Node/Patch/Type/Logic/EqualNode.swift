//
//  EqualNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/7/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct EqualsPatchNode: PatchNodeDefinition {
    static let patch = Patch.equals
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
                ),
                .init(
                    defaultValues: [.number(0)],
                    label: "Threshold"
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

