//
//  SizePackNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/23/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct SizePackPatchNode: PatchNodeDefinition {
    static let patch = Patch.sizePack

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(inputs: [
            .init(
                label: "W",
                staticType: .layerDimension
            ),
            .init(
                label: "H",
                staticType: .layerDimension
            )
        ],
        outputs: [
            .init(type: .size)
        ])
    }

}

@MainActor
func sizePackEval(inputs: PortValuesList,
                  outputs: PortValuesList) -> PortValuesList {
    resultsMaker(inputs)(sizePackOp)
}
