//
//  ShapeToCommandsNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/12/23.
//

import Foundation
import StitchSchemaKit

func getDemoShape(jsonString: String = sampleCurveToJSON) -> CustomShape {
    let json: JSONShapeCommands = parseJSON(jsonString)!
        .parseAsPathCommands()!
        .asJSONShapeCommands!
    return .init(ShapeAndRect.custom(json))
}

@MainActor
func ShapeToCommandsNode(id: NodeId,
                         position: CGSize = .zero,
                         zIndex: Double = 0) -> PatchNode {

    let startingShape: CustomShape = getDemoShape()

    let inputs = toInputs(
        id: id,
        values: ("Shape", [.shape(startingShape)])
    )

    // turn the first union-shape (of the first PortValue.shape in the loop),
    // into a loop of ShapeCommands:
    let commandsLoop: [ShapeCommand] = startingShape.shapes.fromShapeToShapeCommandLoop!

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values: ("Commands", commandsLoop.map(PortValue.shapeCommand)))

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .shapeToCommands,
        inputs: inputs,
        outputs: outputs)

}

func shapeToCommandsEval(inputs: PortValuesList,
                         outputs: PortValuesList) -> PortValuesList {

    if let shapeInput = inputs.first,
       let firstShape = shapeInput.first?.getShape,
       let commands = firstShape.shapes.fromShapeToShapeCommandLoop {
        return [
            commands.map(PortValue.shapeCommand)
        ]
    }

    // Else return current outputs
    // TODO: per our domain logic, it is ALWAYS possible to turn a Shape into a loop of ShapeCommands;
    // however, this is not yet implemented for e.g. oval shapes.
    // For now, we return current outputs.
    return outputs

}
