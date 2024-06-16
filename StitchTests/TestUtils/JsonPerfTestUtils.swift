//
//  JsonPerfTestUtils.swift
//  StitchTests
//
//  Created by Christian J Clampitt on 5/4/23.
//

import Foundation
import StitchSchemaKit
import SwiftyJSON
@testable import Stitch

// Previously used in main app; now just for benchmarking tests
// TODO: re-introduce coordinate space
extension JSON {
    func parseAsJSONShapeCommands(_ coordinateSpace: CGPoint = defaultJsonToShapeCoordinateSpace) -> JSONShapeCommandParseResult {

        let json = self

        let path = json[JSONShapeKeys.PATH]

        if path == .null {
            return .error(.pathKeyMissing)
        }

        guard let pathArray = path.array else {
            return .error(.pathShouldBeArray)
        }

        var parsedCommands = [JSONShapeCommand]()

        for j in pathArray {
            //            log("parseAsJSONShapeCommands: j: \(j)")

            let _type = j[JSONShapeKeys.TYPE]

            if _type == .null {
                //                log("parseAsJSONShapeCommands: could not retrieve type")
                return .error(.typeKeyMissing)
            }

            guard _type.description == JSONShapeKeys.MOVE_TO
                    || _type.description == JSONShapeKeys.LINE_TO
                    || _type.description == JSONShapeKeys.CURVE_TO else {
                return .error(.unrecognizedTypeKeyValue)
            }
            // Every key should contain a point
            let _point = j[JSONShapeKeys.POINT]

            if _point == .null {
                return .error(.pointKeyMissing)
            }
            guard let _x: Double = _point.caseInsensitiveX else {
                return .error(.xKeyMalformed)
            }
            guard let _y: Double = _point.caseInsensitiveY else {
                return .error(.yKeyMalformed)
            }

            let xy = CGPoint(x: _x * coordinateSpace.x,
                             y: _y * coordinateSpace.y)

            //            log("parseAsJSONShapeCommands: _x: \(_x)")
            //            log("parseAsJSONShapeCommands: _y: \(_y)")

            // Then do specific actions per key:

            // moveTo
            if _type.description == JSONShapeKeys.MOVE_TO {
                //                log("parseAsJSONShapeCommands: moveTo")
                parsedCommands.append(.moveTo(xy))
            }
            // lineTo
            else if _type.description == JSONShapeKeys.LINE_TO {
                //                log("parseAsJSONShapeCommands: lineTo")
                parsedCommands.append(.lineTo((xy)))
            }
            // curveTo
            else if _type.description == JSONShapeKeys.CURVE_TO {
                //                log("parseAsJSONShapeCommands: cubic curveTo")

                let curveTo = j[JSONShapeKeys.CURVE_TO]

                guard let curveToX = curveTo.caseInsensitiveX else {
                    return .error(.xKeyMalformed)
                }
                guard let curveToY = curveTo.caseInsensitiveY else {
                    //                    log("parseAsJSONShapeCommands: could not retrieve curveTo data")
                    return .error(.yKeyMalformed)
                }
                //                log("parseAsJSONShapeCommands: curveTo: \(curveTo)")

                let curveToPoint = CGPoint(
                    x: curveToX * coordinateSpace.x,
                    y: curveToY * coordinateSpace.y)

                //                log("parseAsJSONShapeCommands: curveToX: \(curveToX)")
                //                log("parseAsJSONShapeCommands: curveToY: \(curveToY)")

                let curveFrom = j[JSONShapeKeys.CURVE_FROM]
                guard let curveFromX = curveFrom.caseInsensitiveX else {
                    //                    log("parseAsJSONShapeCommands: could not retrieve curveFrom data")
                    return .error(.xKeyMalformed)
                }
                guard let curveFromY = curveFrom.caseInsensitiveY else {
                    //                    log("parseAsJSONShapeCommands: could not retrieve curveFrom data")
                    return .error(.yKeyMalformed)
                }
                //                log("parseAsJSONShapeCommands: curveFrom: \(curveFrom)")
                let curveFromPoint = CGPoint(
                    x: curveFromX * coordinateSpace.x,
                    y: curveFromY * coordinateSpace.y)

                //                log("parseAsJSONShapeCommands: curveFromX: \(curveFromX)")
                //                log("parseAsJSONShapeCommands: curveFromY: \(curveFromY)")

                // TODO: use proper _JSONCurveTo once we can migrate PortValues
                //                parsedCommands.append(.curveTo(_JSONCurveTo(
                //                    point: xy,
                //                    curveFrom: curveFromPoint,
                //                    curveTo: curveToPoint)))

                parsedCommands.append(.curveTo(
                                        .init(point: xy,
                                              controlPoint1: curveFromPoint,
                                              controlPoint2: curveToPoint)))
            }

            // unrecognized command in json
            else {
                //                log("parseAsJSONShapeCommands: unrecognized type")
                return .error(.unrecognizedTypeKeyValue)
            }
        } // for j in ....

        //        log("parseAsJSONShapeCommands: commands: \(commands)")
        return .commands(parsedCommands)
    }
}
