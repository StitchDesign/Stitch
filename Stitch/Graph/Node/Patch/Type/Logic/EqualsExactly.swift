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

