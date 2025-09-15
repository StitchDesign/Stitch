//
//  CommandsToShapeNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/12/23.
//

import Foundation
import StitchSchemaKit

struct CommandsToShapePatchNode: PatchNodeDefinition {
    static let patch = Patch.commandsToShape
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: getDemoShape().shapes.fromShapeToShapeCommandLoop?.map(PortValue.shapeCommand) ?? [],
                    label: "Commands"
                )
            ],
            outputs: [
                .init(
                    label: "Shape",
                    type: .shape
                )
            ]
        )
    }
}


func commandsToShapeEval(inputs: PortValuesList,
                         outputs: PortValuesList) -> PortValuesList {

    if let commandsInput = inputs.first,
       let jsonCommands = commandsInput
        .compactMap(\.shapeCommand)
        .asJSONShapeCommands {

        return [
            [.shape(.init(ShapeAndRect.custom(jsonCommands)))]
        ]
    }

    #if DEV_DEBUG
    log("commandsToShapeEval: could not create shape from commands")
    #endif
    return [
        [.shape(nil)]
    ]
}
