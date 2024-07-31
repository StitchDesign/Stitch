//
//  jsonTests.swift
//  prototypeTests
//
//  Created by Christian J Clampitt on 7/16/21.
//

import StitchSchemaKit
import SwiftyJSON
import XCTest
@testable import Stitch

class JsonTests: XCTestCase {

    @MainActor
    func testJSONFriendlyFormatEncoding() throws {
        let values = [
            PortValue.position(.zero),
            PortValue.position(.init(width: 9, height: 9))
            //            PortValue.number(.zero),
            //            PortValue.number(9)
        ]
            .map { JSONFriendlyFormat(value: $0) }

        let encoded = try! JSONEncoder().encode(values)
        let result = try! JSON(data: encoded)
        //            log("testJSONFriendlyFormatEncoding: values: \(values)")
        //            log("testJSONFriendlyFormatEncoding: encoded: \(encoded)")
        //            log("testJSONFriendlyFormatEncoding: result: \(result)")
    }

    @MainActor
    func testAppendToJSONArray() throws {

        // Appending simple json array to empty json array;
        // result is nested array.
        let expected = parseJSON("[\(JSON.validArray.description)]")

        XCTAssertEqual(
            JSON.emptyArray.appendToJSONArray(.json(.init(.validArray))),
            expected)

        // Appending to JSON object should fail
        XCTAssertEqual(
            JSON.emptyObject.appendToJSONArray(.json(.init(.validArray))),
            nil)

        // Appending CGSize to empty json array
        let size: PortValue = .size(.init(width: 50, height: 60))

        XCTAssertEqual(
            JSON.emptyArray.appendToJSONArray(size),
            size.createJSONFormat().jsonWrapper)

        // Appending number to empty json array
        let number = PortValue.number(99)
        XCTAssertEqual(
            JSON.emptyArray.appendToJSONArray(number),
            number.createJSONFormat().jsonWrapper)

    }

    @MainActor
    func testJSONArrayFromValues() throws {

        let actual = JSON.jsonArrayFromValues([
            .number(1)
        ])
        let expected = parseJSON("[1]")

        XCTAssertEqual(actual, expected)

        let actual2 = JSON.jsonArrayFromValues([
            .number(1),
            .number(2),
            .number(3)
        ])
        let expected2 = parseJSON("[1, 2, 3]")

        XCTAssertEqual(actual2, expected2)

        let actual3 = JSON.jsonArrayFromValues([
            .size(.init(width: 51, height: 91)),
            .size(.init(width: 52, height: 92)),
            .size(.init(width: 53, height: .auto))
        ])

        let expected3 = parseJSON("""
        [
          {
            "height" : "91.0",
            "width" : "51.0"
          },
          {
            "height" : "92.0",
            "width" : "52.0"
          },
          {
            "height" : "auto",
            "width" : "53.0"
          }
        ]
        """)

        XCTAssertEqual(actual3, expected3)

        let actual4 = JSON.jsonArrayFromValues([
            .json(.init(.moveTo)),
            .json(.init(.curveTo))
        ])

        let expected4 = parseJSON("""
        [
          {
            "path" : [
              {
                "point" : {
                  "y" : 0,
                  "x" : 0
                },
                "type" : "moveTo"
              },
              {
                "point" : {
                  "y" : 100,
                  "x" : 100
                },
                "type" : "lineTo"
              },
              {
                "point" : {
                  "y" : 200,
                  "x" : 200
                },
                "type" : "lineTo"
              }
            ]
          },
          {
            "path" : [
              {
                "point" : {
                  "x" : 0,
                  "y" : 0
                },
                "type" : "moveTo"
              },
              {
                "point" : {
                  "x" : 100,
                  "y" : 100
                },
                "type" : "lineTo"
              },
              {
                "curveFrom" : {
                  "x" : 150,
                  "y" : 100
                },
                "type" : "curveTo",
                "point" : {
                  "x" : 200,
                  "y" : 200
                },
                "curveTo" : {
                  "x" : 150,
                  "y" : 200
                }
              }
            ]
          }
        ]
        """)

        XCTAssertEqual(actual4, expected4)

    }

    //    func testCoercingValuesToJSON() throws {
    //
    //        let jsonKey = "love"
    //
    //        let position: PortValue = .position(.init(width: 80, height: 90))
    //
    //        let expectedPositionJSON = parseJSON(position.jsonCompatibleDisplay)!
    //
    //        let json = JSONObjectFromKeyAndValue(jsonKey, position)
    //
    //        // the value of the 'love' key is itself another json
    //        XCTAssertEqual(json[jsonKey],
    //                       expectedPositionJSON)
    //
    //        let number: PortValue = .number(12)
    //
    //        let expectedNumber: String = number.jsonCompatibleDisplay
    //
    //        let json2 = JSONObjectFromKeyAndValue(jsonKey, number)
    //
    //        // the value of the 'love' key is itself another json
    //        XCTAssertEqual(json2[jsonKey].doubleValue,
    //                       Double(expectedNumber)!)
    //
    //        let string: PortValue = .string("dog")
    //
    //        let expectedString: String = string.display
    //
    //        let json3 = JSONObjectFromKeyAndValue(jsonKey, string)
    //
    //        // the value of the 'love' key is itself another json
    //        XCTAssertEqual(json3[jsonKey].stringValue,
    //                       expectedString)
    //    }

}
