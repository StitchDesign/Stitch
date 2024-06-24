//
//  mathTests.swift
//  StitchTests
//
//  Created by Christian J Clampitt on 7/12/22.
//

import XCTest
@testable import Stitch

// Whether a trig function expects and/or returns `degrees vs radians` is untyped and implicit;
// hence the need for these tests.
class mathTests: XCTestCase {

    func testConversions() throws {
        XCTAssertEqual(
            1.5707.radiansToDegrees.rounded(.up),
            90)

        XCTAssertEqual(
            1.5708,
            Double(90.degreesToRadians).rounded(toPlaces: 4))
    }

    // Swift `sin(n)` expects RADIANS
    func testSine() throws {

        // Trying to match Origami examples
        XCTAssertEqual(
            1,
            sin(90.0.degreesToRadians))

        XCTAssertEqual(
            0,
            sin(0.degreesToRadians))

        XCTAssert(areEquivalent(
                    n: 0.70711,
                    n2: sin(45.degreesToRadians)))

    }

    // Swift `cos(n)` expects RADIANS

    // 90 degrees = 1.5707963 radians
    func testCosine() throws {
        // cos
        XCTAssertEqual(
            0,
            Double(cos(1.5707)).rounded(toPlaces: 1))

        XCTAssertEqual(
            1,
            cos(0.0))

        XCTAssertEqual(
            0.70711,
            cos(45.degreesToRadians).rounded(toPlaces: 5))

        XCTAssertEqual(
            0.0,
            cos(90.degreesToRadians).rounded(toPlaces: 5))
    }
}
