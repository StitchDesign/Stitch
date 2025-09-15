//
//  LoopNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct LoopStartPatchNode: PatchNodeDefinition {
    static let patch = Patch.loop
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(3)],
                    label: "Count"
                )
            ],
            outputs: [
                .init(
                    label: "Index",
                    type: .number
                )
            ]
        )
    }
}

