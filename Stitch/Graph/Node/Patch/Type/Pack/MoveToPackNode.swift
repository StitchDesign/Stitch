//
//  MoveToPackNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/26/24.
//

import Foundation
import StitchSchemaKit

struct MoveToPackPatchNode: PatchNodeDefinition {
    static let patch = Patch.moveToPack

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(inputs: [
            NodeInputDefinition.init(label: "Point",
                                  staticType: .position)
        ],
        // what will this default to?
        // Ah, ShapeCommand outputs just show their enum-case type, not their fields
              outputs: [
                .init(type: .shapeCommand)
              ])
    }
}

func moveToPackEval(inputs: PortValuesList,
                    outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { values in
        if let value = values.first?.getPosition {
            return PortValue.shapeCommand(.moveTo(point: value.toPathPoint))
        } else {
            fatalErrorIfDebug()
            return .shapeCommand(.moveTo(point: .zero))
        }
    }

    return resultsMaker(inputs)(op)
}
