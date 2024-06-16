//
//  MatrixUnpackNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/23/24.
//

import Foundation
import StitchSchemaKit

struct MatrixUnpackPatchNode: PatchNodeDefinition {
    static let patch = Patch.matrixTransformUnpack

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(inputs: .singleUnlabeledInput(.matrixTransform),
              outputs: [.init(label: "Position X",
                              type: .number),
                        .init(label: "Position Y",
                              type: .number),
                        .init(label: "Position Z",
                              type: .number),
                        .init(label: "Scale X",
                              type: .number),
                        .init(label: "Scale Y",
                              type: .number),
                        .init(label: "Scale Z",
                              type: .number),
                        .init(label: "Rotation X",
                              type: .number),
                        .init(label: "Rotation Y",
                              type: .number),
                        .init(label: "Rotation Z",
                              type: .number),
                        .init(label: "Rotation Real",
                              type: .number)])
    }
}

func matrixTransformUnpackEval(inputs: PortValuesList,
                               outputs: PortValuesList) -> PortValuesList {

    outputEvalHelper10(inputs: inputs,
                       outputs: [],
                       operation: matrixUnpackOp)
}
