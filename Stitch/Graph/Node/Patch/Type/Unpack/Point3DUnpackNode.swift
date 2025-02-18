//
//  Point3DUnpackNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/23/24.
//

import Foundation
import StitchSchemaKit

struct Point3DUnpackPatchNode: PatchNodeDefinition {
    static let patch = Patch.point3DUnpack

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(inputs: .singleUnlabeledInput(.point3D),
              outputs: [
                .init(label: "X",
                      type: .number),
                .init(label: "Y",
                      type: .number),
                .init(label: "Z",
                      type: .number)
              ])
    }
}

@MainActor
func point3DUnpackEval(inputs: PortValuesList,
                       outputs: PortValuesList) -> PortValuesList {
    resultsMaker3(inputs)(point3DUnpackOp)
}
