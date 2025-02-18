//
//  Point4DUnpackNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/23/24.
//

import Foundation
import StitchSchemaKit

struct Point4DUnpackPatchNode: PatchNodeDefinition {
    static let patch = Patch.point4DUnpack

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(inputs: .singleUnlabeledInput(.point4D),
              outputs: [
                .init(label: "X",
                      type: .number),
                .init(label: "Y",
                      type: .number),
                .init(label: "Z",
                      type: .number),
                .init(label: "W",
                      type: .number)
              ])
    }
}

@MainActor
func point4DUnpackEval(inputs: PortValuesList,
                       outputs: PortValuesList) -> PortValuesList {
    resultsMaker4(inputs)(point4DUnpackOp)
}
