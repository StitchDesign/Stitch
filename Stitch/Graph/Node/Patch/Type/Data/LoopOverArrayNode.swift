//
//  LoopOverArrayNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/13/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import SwiftyJSON

struct LoopOverArrayPatchNode: PatchNodeDefinition {
    static let patch = Patch.loopOverArray
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.json(emptyStitchJSONObject)],
                    label: "Array"
                )
            ],
            outputs: [
                .init(
                    label: "Index",
                    type: .number
                ),
                .init(
                    label: "Items",
                    type: .json
                )
            ]
        )
    }
}

