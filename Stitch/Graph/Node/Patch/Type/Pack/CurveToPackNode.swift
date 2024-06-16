//
//  CurveToPackNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/26/24.
//

import Foundation
import StitchSchemaKit

struct CurveToPackPatchNode: PatchNodeDefinition {
    static let patch = Patch.curveToPack

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(inputs: [
            NodeInputDefinition.init(label: "Point",
                                  staticType: .position),
            NodeInputDefinition.init(label: "Curve From",
                                  staticType: .position),
            NodeInputDefinition.init(label: "Curve To",
                                  staticType: .position)
        ],
        outputs: [
            .init(type: .shapeCommand)
        ])
    }
}

func curveToPackEval(inputs: PortValuesList,
                     outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { values in
        if let point = values.first?.getPosition,
           let curveFrom = values[safe: 1]?.getPosition,
           let curveTo = values[safe: 2]?.getPosition {
            return .shapeCommand(
                .curveTo(curveFrom: curveFrom.toPathPoint,
                         point: point.toPathPoint,
                         curveTo: curveTo.toPathPoint)
            )
        } else {
            #if DEUBG || DEV_DEBUG
            fatalError()
            #endif
            return .shapeCommand(.curveTo(curveFrom: .zero,
                                          point: .zero,
                                          curveTo: .zero))
        }
    }

    return resultsMaker(inputs)(op)
}
