//
//  SizeUnpackNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/23/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct SizeUnpackPatchNode: PatchNodeDefinition {
    static let patch = Patch.sizeUnpack

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(inputs: .singleUnlabeledInput(.size),
              outputs: [
                .init(label: "W",
                      type: .number),
                .init(label: "H",
                      type: .number)
              ])
    }
}

func sizeUnpackEval(inputs: PortValuesList,
                    outputs: PortValuesList) -> PortValuesList {
    resultsMaker2(inputs)(sizeUnpackOp)
}
