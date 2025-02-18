//
//  CurveToUnpackNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/26/24.
//

import Foundation
import StitchSchemaKit

struct CurveToUnpackPatchNode: PatchNodeDefinition {
    static let patch = Patch.curveToUnpack

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        // What will this default to?
        .init(inputs: [
            .init(defaultValues: [.shapeCommand(.defaultFalseCurveTo)],
                  label: "",
                  isTypeStatic: true)
        ],
        outputs: [
            .init(label: "Point",
                  type: .position),
            .init(label: "Curve From",
                  type: .position),
            .init(label: "Curve To",
                  type: .position)
        ])
    }
}

@MainActor
func curveToUnpackEval(inputs: PortValuesList,
                       outputs: PortValuesList) -> PortValuesList {
    //    resultsMaker2(inputs)(curveToUnpackOp)
    //    fatalError()

    let op: Operation3 = { (values: PortValues) -> (PortValue, PortValue, PortValue) in
        if let shapeCommand = values.first?.shapeCommand {
            return (
                .position(shapeCommand.getPoint?.asCGPoint ?? .zero),
                .position(shapeCommand.getCurveFrom?.asCGPoint ?? .zero),
                .position(shapeCommand.getCurveTo?.asCGPoint ?? .zero)
            )
        } else {
            #if DEV || DEV_DEBUG
            fatalError()
            #endif
            let shapeCommand: ShapeCommand = .defaultFalseShapeCommand
            return (
                .position(shapeCommand.getPoint?.asCGPoint ?? .zero),
                .position(shapeCommand.getCurveFrom?.asCGPoint ?? .zero),
                .position(shapeCommand.getCurveTo?.asCGPoint ?? .zero)
            )
        }
    }

    return resultsMaker3(inputs)(op)

}
