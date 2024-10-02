//
//  jsonPerfTests.swift
//  StitchTests
//
//  Created by Christian J Clampitt on 4/26/23.
//

import XCTest
@testable import Stitch
import SwiftyJSON

// Performance test failures not considered blocking.
final class jsonPerfTests: XCTestCase {
//
//    // SwiftyJSON.rawData + JSONDecoder<PathCommands>
//    // parseTestJSON: 0.219
//    // sampleCurveToJSON: 0.385, 0.381, 0.383
//    // sampleCurveToJSON + PathCommands.asJSONShapeCommands: 0.393
//    func testJSONToShapePerf() throws {
//        //        let jsons = manyJSONS(parseJSON(parseTestJSON)!)
//
//        let jsons = manyJSONS(parseJSON(sampleCurveToJSON)!,
//                              count: 8000)
//
//        // May 12: 0.382, 0.377, 0.387
//        self.measure {
//            jsons.forEach {
//                // turning a path array json into a shape;
//                // same logic as `jsonToShapeEval`
//                $0.parseAsPathCommands().map(\.asJSONShapeCommands)!
//            }
//        }
//    }
//
//    func testCommandsToShapePerf() throws {
//        let manyCommands = Array(repeating: getDemoShape(jsonString: sampleCurveToJSON).shapes.fromShapeToShapeCommandLoop!,
//                                 count: 8000)
//
//        // May 12: 0.005, 0.005, 0.00484
//        self.measure {
//            manyCommands.forEach { commands in
//                // turning a loop of shape-commands into a shape;
//                // same logic as `commandsToShapeEval`
//                commands.asJSONShapeCommands!
//            }
//        }
//    }

    //    func testCommandTypeSerialization() throws {
    //        let commandType: ShapeCommandType = .closePath
    //        let encoded = try! JSONEncoder().encode(commandType)
    //        let decoded = try! JSONDecoder().decode(ShapeCommandType.self, from: encoded)
    //        log("testCommandTypeSerialization: commandType: \(commandType)")
    //        log("testCommandTypeSerialization: encoded: \(encoded)")
    //        log("testCommandTypeSerialization: decoded: \(decoded)")
    //    }
    //
    //    func testShapeCommandSerialization() throws {
    //        let commandType: ShapeCommand = .closePath
    //        let encoded = try! JSONEncoder().encode(commandType)
    //        let decoded = try! JSONDecoder().decode(ShapeCommand.self, from: encoded)
    //        log("testShapeCommandSerialization: commandType: \(commandType)")
    //        log("testShapeCommandSerialization: encoded: \(encoded)")
    //        log("testShapeCommandSerialization: decoded: \(decoded)")
    //    }
    //
    //    func testShapeToJSON() throws {
    //
    //        // JSON -> Shape
    //        let json: JSON = parseJSON(sampleCurveToJSON)!
    //        let commands: JSONShapeCommands = json.parseAsPathCommands()!.asJSONShapeCommands!
    //        let shape: CustomShape = .init(ShapeAndRect.custom(commands))
    //
    //        // Shape -> JSON
    //        let shapeJSON: JSON = shape.asJSON
    //
    //        //        print("shapeJSON: \(shapeJSON.description)")
    //
    //        XCTAssert(shapeJSON.isEqualTo(json))
    //    }

    //    // 0.092, 0.082, 0.080, 0.080, 0.079
    //    func testLoopToArray_loopToArrayEval2() throws {
    //        let inputLoop: PortValues = [
    //            .number(1),
    //            .number(2),
    //            .number(3)
    //        ]
    //        let xs = Array(repeating: inputLoop, count: 8000)
    //        self.measure {
    //            xs.forEach { x in
    //                loopToArrayEval2(inputs: [x],
    //                                 outputs: [])
    //            }
    //        }
    //    }
    //
    //
    //    // uses native SwiftUI methods: Data, JSONDecoder<Codable>
    //    // 0.179, 0.170, 0.168, 0.158
    //    func testParseCommandsSwift() throws {
    //        let strings = Array(repeating: parseTestJSON,
    //                            count: 8000)
    //        self.measure {
    //            strings.forEach {
    //                $0.parseCommands()
    //            }
    //        }
    //    }
    //
    //    // 0.185, 0.191
    //    // When using full struct / enum: 0.243, 0.273, 0.244
    //    func testParseCommandsSwift2() throws {
    //
    //        //        let strings = Array(repeating: parseTestJSON2,
    //        let strings = Array(repeating: sampleCurveToJSON,
    //                            // the simple case, but using an enum in the PathCommands struct
    //                            //        let strings = Array(repeating: parseTestJSON,
    //                            count: 8000)
    //        self.measure {
    //            strings.forEach {
    //                $0.parseCommands()
    //            }
    //        }
    //    }
    //
    //
    //    // pulls keys from SwiftyJSON
    //    // parseTestJSON: 0.451, 0.430, 0.40, 0.385
    //    // sampleCurveToJSON: 0.81, 0.813
    //    func testParseCommandsSwiftyJSON() throws {
    //        //        let jsons = manyJSONS(parseJSON(parseTestJSON)!)
    //        let jsons = manyJSONS(parseJSON(sampleCurveToJSON)!)
    //        self.measure {
    //            jsons.forEach {
    //                $0.parseAsJSONShapeCommands()
    //            }
    //        }
    //    }
    //
    //    // TESTING SMALL, DIFFERENT JSONS
    //
    //    func testSwiftyJSONEquals() throws {
    //        let js1 = manyJSONS()
    //        let js2 = manyJSONS(validComplexJSON)
    //        self.measure {
    //            zip(js1, js2).forEach {
    //                $0 == $1
    //            }
    //        }
    //    }
    //
    //    func testStitchJSONEquals() throws {
    //        let sjs1 = manyStitchJSONS()
    //        let sjs2 = manyStitchJSONS(validComplexJSON)
    //        self.measure {
    //            zip(sjs1, sjs2).forEach {
    //                $0 == $1
    //            }
    //        }
    //    }
    //
    //    // TESTING SAME JSONS
    //
    //    func testSwiftyJSONEquals2() throws {
    //        let js1 = manyJSONS()
    //        let js2 = manyJSONS()
    //        self.measure {
    //            zip(js1, js2).forEach {
    //                $0 == $1
    //            }
    //        }
    //    }
    //
    //    func testStitchJSONEquals2() throws {
    //        let sjs1 = manyStitchJSONS()
    //        let sjs2 = manyStitchJSONS()
    //        self.measure {
    //            zip(sjs1, sjs2).forEach {
    //                $0 == $1
    //            }
    //        }
    //    }
    //
    //    func testSwiftyJSONEquals3() throws {
    //        let json = parseJSON(sampleNegativeCurveToJSON)!
    //        let js1 = manyJSONS(json)
    //        let js2 = manyJSONS(json)
    //        self.measure {
    //            zip(js1, js2).forEach {
    //                $0 == $1
    //            }
    //        }
    //    }
    //
    //    func testStitchJSONEquals3() throws {
    //        let json = parseJSON(sampleNegativeCurveToJSON)!
    //        let sjs1 = manyStitchJSONS(json)
    //        let sjs2 = manyStitchJSONS(json)
    //        self.measure {
    //            zip(sjs1, sjs2).forEach {
    //                $0 == $1
    //            }
    //        }
    //    }
    //
    //    // Wrapped in the PortValue.json case
    //    func testStitchJSONEquals4() throws {
    //        let json = parseJSON(sampleNegativeCurveToJSON)!
    //        let sjs1 = manyStitchJSONS(json).map(PortValue.json)
    //        let sjs2 = manyStitchJSONS(json).map(PortValue.json)
    //        self.measure {
    //            zip(sjs1, sjs2).forEach {
    //                $0 == $1
    //            }
    //        }
    //    }
    //
    //    // TESTING INTEGERS AND STRINGS (BASELINE)
    //
    //    func testIntegerEquals() throws {
    //        let sjs1 = Array.init(repeating: 1, count: 8000)
    //        let sjs2 = Array.init(repeating: 2, count: 8000)
    //        self.measure {
    //            zip(sjs1, sjs2).forEach {
    //                $0 == $1
    //            }
    //        }
    //    }
    //
    //    func testIntegerEquals2() throws {
    //        let sjs1 = Array.init(repeating: 1, count: 8000)
    //        let sjs2 = Array.init(repeating: 1, count: 8000)
    //        self.measure {
    //            zip(sjs1, sjs2).forEach {
    //                $0 == $1
    //            }
    //        }
    //    }
    //
    //    func testStringEquals() throws {
    //        let sjs1 = Array.init(repeating: "love", count: 8000)
    //        let sjs2 = Array.init(repeating: "joy", count: 8000)
    //        self.measure {
    //            zip(sjs1, sjs2).forEach {
    //                $0 == $1
    //            }
    //        }
    //    }
    //
    //    func testStringEquals2() throws {
    //        let sjs1 = Array.init(repeating: "love", count: 8000)
    //        let sjs2 = Array.init(repeating: "love", count: 8000)
    //        self.measure {
    //            zip(sjs1, sjs2).forEach {
    //                $0 == $1
    //            }
    //        }
    //    }
    //
    //    func testStringEquals3() throws {
    //        let sjs1 = Array.init(repeating: sampleNegativeCurveToJSON,
    //                              count: 8000)
    //        let sjs2 = Array.init(repeating: validComplexRawJSON,
    //                              count: 8000)
    //        self.measure {
    //            zip(sjs1, sjs2).forEach {
    //                $0 == $1
    //            }
    //        }
    //    }
    //
    //    func testStringEquals4() throws {
    //        let sjs1 = Array.init(repeating: sampleNegativeCurveToJSON,
    //                              count: 8000)
    //        let sjs2 = Array.init(repeating: sampleNegativeCurveToJSON,
    //                              count: 8000)
    //        self.measure {
    //            zip(sjs1, sjs2).forEach {
    //                $0 == $1
    //            }
    //        }
    //    }

}
