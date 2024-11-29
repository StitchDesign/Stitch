//
//  ClosePathPackNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/26/24.
//

import Foundation
import StitchSchemaKit

struct ClosePathPatchNode: PatchNodeDefinition {
    static let patch = Patch.closePath

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(inputs: [
            .init(defaultValues: [.shapeCommand(.closePath)],
                  label: "")
        ],
        // what will this default to?
        // Ah, ShapeCommand outputs just show their enum-case type, not their fields
        outputs: [
            .init(type: .shapeCommand)
        ])
    }
}

@MainActor
func closePathEval(inputs: PortValuesList,
                   outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { _ in
        .shapeCommand(.closePath)
    }

    return resultsMaker(inputs)(op)
}
