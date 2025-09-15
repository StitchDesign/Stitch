//
//  RunningTotalNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/2/22.
//

import Foundation
import StitchSchemaKit

struct RunningTotalPatchNode: PatchNodeDefinition {
    static let patch = Patch.runningTotal
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(0)],
                    label: "Loop"
                )
            ],
            outputs: [
                .init(
                    label: "",
                    type: .number
                )
            ]
        )
    }
}

