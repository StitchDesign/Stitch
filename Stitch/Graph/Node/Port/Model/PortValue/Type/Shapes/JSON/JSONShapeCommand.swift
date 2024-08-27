//
//  JSONShape.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/16/23.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import SwiftyJSON

typealias JSONShapeCommands = [JSONShapeCommand]

extension JSONShapeCommand {
    // turn an individual shape command into a json object
    var toJSON: Result<JSON, Error> {
        switch self {
        case .closePath:
            return JSONClosePath().encode.flatMap(\.toJSONResult)
        case .moveTo(let x):
            return JSONMoveTo(point: x).encode.flatMap(\.toJSONResult)
        case .lineTo(let x):
            return JSONLineTo(point: x).encode.flatMap(\.toJSONResult)
        case .curveTo(let x):
            return _JSONCurveTo(x).encode.flatMap(\.toJSONResult)
        }
    }
}

extension JSONShapeCommands {
    // turn one or more individual shape commands into a json object with a 'path' key
    var asPathCommands: PathCommands {
        .init(path: self.map(\.asShapeCommand))
    }
}

extension JSONShapeCommand {
    var asShapeCommand: ShapeCommand {
        switch self {
        case .closePath:
            return .closePath
        case .moveTo(let cGPoint):
            return .moveTo(point: cGPoint.toPathPoint)
        case .lineTo(let cGPoint):
            return .lineTo(point: cGPoint.toPathPoint)
        case .curveTo(let curveTo):
            return .curveTo(curveFrom: curveTo.controlPoint1.toPathPoint,
                            point: curveTo.point.toPathPoint,
                            curveTo: curveTo.controlPoint2.toPathPoint)
        }
    }
}

// struct JsonShape_REPL: View {
//
//    //    var json: JSON = JSON(parseJSON: sampleMoveToJSON)
//    var json: JSON = JSON(parseJSON: sampleCurveToJSON)
//
//    var commands: JSONShapeCommands? {
//        json.parseAsJSONShapeCommands(.init(x: 1, y: 1)).getCommands
//    }
//    var commands2: JSONShapeCommands? {
//        JSON(parseJSON: sampleMoveToJSON)
//            .parseAsJSONShapeCommands(.init(x: 1, y: 1))
//            .getCommands
//    }
//
//    var customShapeView: some View {
//        ZStack {
//            Color.gray.zIndex(-1).opacity(0.5)
//            JSONCustomShape(jsonCommands: commands!)
//                .stroke(.green)
//            //                .fill(.purple)
//        }
//    }
//
//    var customShape: CustomShape {
//        //        CustomShape(.custom(commands!))
//        CustomShape(.custom(commands!), .custom(commands2!))
//    }
//
//    var body: some View {
//        //        customShapeView
//        //        VStack(spacing: 60) {
//        HStack(spacing: 60) {
//            Text("json: \(json.description)")
//            //            Text("commands: \(commands!.debugDescription)")
//            Text("\(commands?.toJSON.description ?? "No Json...")")
//            Text("customShape.asJSON: \(customShape.asJSON.description)")
//        }
//
//        //        Text("\(commands?.debugDescription)")
//    }
// }
//
// struct JsonShapePlay_Previews: PreviewProvider {
//    static var previews: some View {
//        JsonShape_REPL()
//    }
// }
