//
//  LineToPackNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/26/24.
//

import Foundation
import StitchSchemaKit

struct LineToPackPatchNode: PatchNodeDefinition {
    static let patch = Patch.lineToPack

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(inputs: [
            NodeInputDefinition.init(label: "Point",
                                  staticType: .position)
        ],
        outputs: [
            .init(type: .shapeCommand)
        ])
    }
}

@MainActor
func lineToPackEval(inputs: PortValuesList,
                    outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { values in
        if let value = values.first?.getPosition {
            return PortValue.shapeCommand(.lineTo(point: value.toPathPoint))
        } else {
            #if DEUBG || DEV_DEBUG
            fatalError()
            #endif
            return .shapeCommand(.lineTo(point: .zero))
        }
    }

    return resultsMaker(inputs)(op)
}
