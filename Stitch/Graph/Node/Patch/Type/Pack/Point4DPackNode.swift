//
//  Point4DPack.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/23/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct Point4DPackPatchNode: PatchNodeDefinition {
    static let patch = Patch.point4DPack

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(inputs: [
            .init(label: "X",
                  staticType: .number),
            .init(label: "Y",
                  staticType: .number),
            .init(label: "Z",
                  staticType: .number),
            .init(label: "W",
                  staticType: .number)
        ], outputs: [
            .init(type: .point4D)
        ])
    }
}

@MainActor
func point4DPackEval(inputs: PortValuesList,
                     outputs: PortValuesList) -> PortValuesList {
    resultsMaker(inputs)(point4DPackOp)
}
