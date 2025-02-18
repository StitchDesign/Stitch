//
//  JSONToShapeNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/16/23.
//

import Foundation
import StitchSchemaKit
@preconcurrency import SwiftyJSON
import SwiftUI

//let JSON_TO_SHAPE_NO_ERROR = ""
extension JSON {
    static let JSON_TO_SHAPE_NO_ERROR: JSON = parseJSON("{ \"Error\": \"None\" }")!
}


@MainActor
func jsonToShapeNode(id: NodeId,
                     position: CGSize = .zero,
                     zIndex: Double = 0) -> PatchNode {

    let startingJson = StitchJSON.emptyJSONObject // JSON(parseJSON: sampleCurveToJSON)

    let inputs = toInputs(
        id: id,
        values:
            ("JSON", [.json(startingJson)]),
        ("Coordinate Space", [.position(defaultJsonToShapeCoordinateSpace)])
    )

    //    let asCommands = startingJson.parseAsJSONShapeCommands().getCommands!
    //    let shape = CustomShape(ShapeAndRect.custom(asCommands))
    //    let sizeShape = asCommands.points.boundingBox

    let outputs = toOutputs(
        id: id, offset: inputs.count,
        values:
            ("Shape", [.shape(nil)]),
        ("Error", [.json(.init(.JSON_TO_SHAPE_NO_ERROR))]),
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

@MainActor
func jsonToShapeEval(inputs: PortValuesList,
                     outputs: PortValuesList) -> PortValuesList {

    let op: Operation3 = { (values: PortValues) -> (PortValue, PortValue, PortValue) in

        if let jsonInput: JSON = values[0].getJSON,

           // TODO: reintroduce proper use of coordinate-space
           let coordinateSpace: StitchPosition = values[1].getPosition {

            if let commands = jsonInput.parseAsPathCommands()?.asJSONShapeCommands {
                return (
                    .shape(CustomShape(.custom(commands))),
                    .json(.init(.JSON_TO_SHAPE_NO_ERROR)),
                    .size(commands.getPoints().boundingBox.toLayerSize)
                )
            } else {
                let errorMessage = JSONShapeCommandParseError.instructionsMalformed.rawValue
                
                return (
                    .shape(nil),
                    // TODO: reintroduce proper error messaging
                    .json(.init(.init(parseJSON: "{ \"Error\": \"\(errorMessage)\" }"))),
                    .size(.zero)
                )
            }

        } else {
            log("jsonToShapeEval: failed to retrieve values from inputs")
            return (
                PortValue.shape(nil),
                PortValue.json(.emptyJSONObject),
                PortValue.size(.zero)
            )
        }
    }

    return resultsMaker3(inputs)(op)
}
