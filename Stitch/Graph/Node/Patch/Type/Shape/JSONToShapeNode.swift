//
//  JSONToShapeNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/16/23.
//

import Foundation
import StitchSchemaKit
import SwiftyJSON
import SwiftUI

@MainActor
func jsonToShapeNode(id: NodeId,
                     position: CGSize = .zero,
                     zIndex: Double = 0) -> PatchNode {

    let startingJson = StitchJSON.emptyJSONObject // JSON(parseJSON: sampleCurveToJSON)

    let inputs = toInputs(
        id: id,
        values:
            ("JSON", [.json(startingJson)]),
        ("Coordinate Space", [.position(defaultJsonToShapeCoordinateSpace.toCGSize)])
    )

    //    let asCommands = startingJson.parseAsJSONShapeCommands().getCommands!
    //    let shape = CustomShape(ShapeAndRect.custom(asCommands))
    //    let sizeShape = asCommands.points.boundingBox

    let outputs = toOutputs(
        id: id, offset: inputs.count,
        values:
            ("Shape", [.shape(nil)]),
        ("Error", [.string(.init("none"))]),
        // the bounding box of the shape
        ("Size", [.size(.zero)])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .jsonToShape,
        inputs: inputs,
        outputs: outputs)
}

func jsonToShapeEval(inputs: PortValuesList,
                     outputs: PortValuesList) -> PortValuesList {

    let op: Operation3 = { (values: PortValues) -> (PortValue, PortValue, PortValue) in

        if let jsonInput: JSON = values[0].getJSON,

           // TODO: reintroduce proper use of coordinate-space
           let coordinateSpace: StitchPosition = values[1].getPosition {

            //            let parseResult = jsonInput
            //                .parseAsJSONShapeCommands(coordinateSpace.toCGPoint)
            if let commands = jsonInput
                .parseAsPathCommands()?.asJSONShapeCommands {
                return (
                    .shape(CustomShape(.custom(commands))),
                    .string(.init("none")),
                    .size(commands.getPoints().boundingBox.toLayerSize)
                )
            } else {
                return (
                    .shape(nil),
                    // TODO: reintroduce proper error messaging
                    .string(.init(JSONShapeCommandParseError.instructionsMalformed.rawValue)),
                    .size(.zero)
                )
            }

            //            switch parseResult {
            //            case .commands(let commands):
            //                return (
            //                    .shape(CustomShape(.custom(commands))),
            //                    .string("none"),
            //                    .size(commands.points.boundingBox.toLayerSize)
            //                )
            //            case .error(let error):
            //                return (
            //                    .shape(nil),
            //                    .string(error.display),
            //                    .size(.zero)
            //                )
            //            }
        } else {
            log("jsonToShapeEval: failed to retrieve values from inputs")
            return (
                PortValue.shape(nil),
                PortValue.string(.init("Inputs error")),
                PortValue.size(.zero)
            )
        }
    }

    return resultsMaker3(inputs)(op)
}
