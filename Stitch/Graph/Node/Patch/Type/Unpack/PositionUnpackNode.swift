//
//  PositionUnpackNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/23/24.
//

import Foundation
import StitchSchemaKit

struct PositionUnpackPatchNode: PatchNodeDefinition {
    static let patch = Patch.positionUnpack

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(inputs: .singleUnlabeledInput(.position),
              outputs: [
                .init(label: "X",
                      type: .number),
                .init(label: "Y",
                      type: .number)
              ])
    }
}

func positionUnpackEval(inputs: PortValuesList,
                        outputs: PortValuesList) -> PortValuesList {
    resultsMaker2(inputs)(positionUnpackOp)
}
