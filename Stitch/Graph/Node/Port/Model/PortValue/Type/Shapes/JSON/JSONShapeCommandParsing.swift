//
//  JSONShapeParsing.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/20/23.
//

import SwiftUI
import SwiftyJSON
import StitchSchemaKit
import Foundation

extension JSON {
    var caseInsensitiveX: Double? {
        self["X"].double ?? self[X].double
    }

    var caseInsensitiveY: Double? {
        self["Y"].double ?? self[Y].double
    }

    var caseInsensitiveZ: Double? {
        self["Z"].double ?? self[Z].double
    }

    var caseInsensitiveW: Double? {
        self["W"].double ?? self[W].double
    }
}

struct JSONClosePath: Equatable, Codable {
    var type: String = JSONShapeKeys.CLOSE_PATH
}

struct JSONMoveTo: Equatable, Codable {
    var type: String = JSONShapeKeys.MOVE_TO
    @CodablePoint var point: CGPoint
    //    var point: CGPoint
}

struct JSONLineTo: Equatable, Codable {
    var type: String = JSONShapeKeys.LINE_TO
    @CodablePoint var point: CGPoint
    //    var point: CGPoint
}

// TODO: replaces `JSONCurveTo` once we're able to migrate PortValues
struct _JSONCurveTo: Equatable, Codable {
    var type = JSONShapeKeys.CURVE_TO

    // the JSON keys
    @CodablePoint var point: CGPoint
    @CodablePoint var curveFrom: CGPoint
    @CodablePoint var curveTo: CGPoint

    // i.e. JSON's `curveFrom`
    var controlPoint1: CGPoint {
        curveFrom
    }

    // i.e. JSON's `curveTo`
    var controlPoint2: CGPoint {
        curveTo
    }

    // Helper
    func getPoints() -> [CGPoint] {
        [point, controlPoint1, controlPoint2]
    }
}

extension _JSONCurveTo {
    init(_ jsonCurveTo: JSONCurveTo) {
        self.point = jsonCurveTo.point
        self.curveFrom = jsonCurveTo.controlPoint1
        self.curveTo = jsonCurveTo.controlPoint2
    }
}

enum JSONShapeCommandParseError: String, Codable, Equatable {

    case pathKeyMissing,
         pathShouldBeArray,
         unrecognizedTypeKeyValue,
         typeKeyMissing,
         pointKeyMissing,
         xKeyMalformed,
         yKeyMalformed,
         instructionsMalformed // catch-all

    var display: String {
        switch self {
        case .pathKeyMissing:
            return "\'path\' key missing"
        case .pathShouldBeArray:
            return "\'path\' should be array"
        case .typeKeyMissing:
            return "\'type\' key missing"
        case .pointKeyMissing:
            return "\'point\' key missing"
        case .unrecognizedTypeKeyValue:
            return "unrecognized value for \'type\' key"
        case .xKeyMalformed:
            return "\'x\' key malformed"
        case .yKeyMalformed:
            return "\'y\' key malformed"
        case .instructionsMalformed:
            return "instructions malformed"

        }

    }
}

// Replace with `Result<JSONShapeCommands, JSONShapeCommandParseError>` ?
// Or `Either<T, K>` ?
// Or make `JSONShapeCommandParseError` conform to `Error`?
enum JSONShapeCommandParseResult: Codable, Equatable {
    case commands(JSONShapeCommands),
         error(JSONShapeCommandParseError)

    var getCommands: JSONShapeCommands? {
        switch self {
        case .commands(let jSONShapeCommands):
            return jSONShapeCommands
        case .error:
            return nil
        }
    }
}

let defaultJsonToShapeCoordinateSpace = CGPoint(x: 1.0, y: 1.0)

let parseTestJSON = """
{
  "path": [
    {
      "type": "lineTo",
      "point": {
        "x": 100,
        "y": 100
      }
    },

    {
      "type": "lineTo",
      "point": {
        "x": 200,
        "y": 200
      }
    },

  ]
}
"""

let parseTestJSON2 = sampleMoveToJSON

struct PathCommands: Equatable, Decodable, Encodable {
    var path: [ShapeCommand]
}

extension [ShapeCommand] {
    var asJSONShapeCommands: JSONShapeCommands? {
        guard !self.isEmpty else {
            return nil
        }

        return self.map { (pathCommand: ShapeCommand) in
            switch pathCommand {
            case .closePath:
                return JSONShapeCommand.closePath

            case .lineTo(let point):
                return JSONShapeCommand.lineTo(point.asCGPoint)

            case .moveTo(let point):
                return JSONShapeCommand.moveTo(point.asCGPoint)

            case .curveTo(let curveFrom,
                          let point,
                          let curveTo):
                return JSONShapeCommand.curveTo(
                    JSONCurveTo(point: point.asCGPoint,
                                controlPoint1: curveFrom.asCGPoint,
                                controlPoint2: curveTo.asCGPoint))
            }
        }
    }
}

extension PathCommands {
    var asJSONShapeCommands: JSONShapeCommands? {
        self.path.asJSONShapeCommands
    }
}

// JSON = SwiftyJSON.JSON
extension JSON {
    func parseAsPathCommands() -> PathCommands? {
        guard let data: Data = try? self.rawData() else {
            return nil
        }
        // TODO: better use do / catch to provide app-user with better understand of how the json was malformed

        /*
         Lower-cases the first letter of each key, so that we properly treat "X" as "x"
         
         Alternatively, manually implement Decodable for ShapeCommand?
         
         Which is better for perf -- custom key-decoding strategy or custom Decodable implementation?
         
         https://developer.apple.com/documentation/foundation/jsondecoder/keydecodingstrategy/custom
         */
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .custom { keys in
            let lowercaseKey = keys.last?.stringValue.lowercaseFirstLetter() ?? ""
            return AnyKey(stringValue: String(lowercaseKey))
        }
        
        #if DEV_DEBUG
        let decoded: PathCommands = try! decoder.decode(PathCommands.self, from: data)
        #else
        let decoded: PathCommands? = try? decoder.decode(PathCommands.self, from: data)
        #endif
        
        // Default decoder fails if ShapeCommand json used "X" instead of "x"; but has better perf?
        // let decoded: PathCommands? = try? JSONDecoder().decode(PathCommands.self, from: data)
        return decoded
    }
}

extension String {
    func lowercaseFirstLetter() -> String {
        return prefix(1).lowercased() + self.dropFirst()
    }

    mutating func lowercaseFirstLetter() {
      self = self.lowercaseFirstLetter()
    }
}

/// An implementation of CodingKey that's useful for combining and transforming keys as strings.
struct AnyKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}
