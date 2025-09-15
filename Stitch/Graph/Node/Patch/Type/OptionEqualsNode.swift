//
//  OptionEqualsNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/23/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct OptionEqualsPatchNode: PatchNodeDefinition {
    static let patch = Patch.optionEquals
    static let defaultUserVisibleType: UserVisibleType? = .string

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.string(.init("a"))],
                    label: "Option"
                ),
                .init(
                    defaultValues: [.string(.init("a"))],
                    label: ""
                ),
                .init(
                    defaultValues: [.string(.init("b"))],
                    label: ""
                )
            ],
            outputs: [
                .init(
                    label: "",
                    type: type ?? .string
                ),
                .init(
                    label: "Equals",
                    type: .bool
                )
            ]
        )
    }
}

