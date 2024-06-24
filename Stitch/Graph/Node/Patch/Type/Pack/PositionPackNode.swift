//
//  PositionPackNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/23/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct PositionPackPatchNode: PatchNodeDefinition {
    static let patch = Patch.positionPack

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(inputs: [
            .init(
                label: "X",
                staticType: .number
            ),
            .init(
                label: "Y",
                staticType: .number
            )
        ],
        outputs: [
            .init(type: .position)
        ])
    }
}

func positionPackEval(inputs: PortValuesList,
                      outputs: PortValuesList) -> PortValuesList {
    resultsMaker(inputs)(positionPackOp)
}
