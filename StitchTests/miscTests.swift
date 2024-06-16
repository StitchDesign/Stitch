//
//  miscTests.swift
//  prototypeTests
//
//  Created by Christian J Clampitt on 8/6/21.
//

import XCTest
@testable import Stitch

class MiscTests: XCTestCase {

    func testGetMultiples() throws {

        let adjustedHeight: CGFloat = 320.67369079589844
        let prevMultiple: CGFloat = 300.0
        let nextMultiple: CGFloat = 325.0
        let result = getMultiples(adjustedHeight)
        XCTAssertEqual(result.0, prevMultiple)
        XCTAssertEqual(result.1, nextMultiple)

        let adjustedHeight1: CGFloat = 707.3457794189453
        let prevMultiple1: CGFloat = 700.0
        let nextMultiple1: CGFloat = 725.0
        let result1 = getMultiples(adjustedHeight1)
        XCTAssertEqual(result1.0, prevMultiple1)
        XCTAssertEqual(result1.1, nextMultiple1)

        let adjustedHeight2: CGFloat = 532.3457794189453
        let prevMultiple2: CGFloat = 525.0
        let nextMultiple2: CGFloat = 550.0
        let result2 = getMultiples(adjustedHeight2)
        XCTAssertEqual(result2.0, prevMultiple2)
        XCTAssertEqual(result2.1, nextMultiple2)

        let adjustedHeight3: CGFloat = 567.3447570800781
        let prevMultiple3: CGFloat = 550.0
        let nextMultiple3: CGFloat = 575.0
        let result3 = getMultiples(adjustedHeight3)
        XCTAssertEqual(result3.0, prevMultiple3)
        XCTAssertEqual(result3.1, nextMultiple3)

        let adjustedHeight4: CGFloat = 279.6986541748047
        let prevMultiple4: CGFloat = 275.0
        let nextMultiple4: CGFloat = 300.0
        let result4 = getMultiples(adjustedHeight4)
        XCTAssertEqual(result4.0, prevMultiple4)
        XCTAssertEqual(result4.1, nextMultiple4)

        // Should these last two results not be allowed?
        let adjustedHeight5: CGFloat = 1100.056105159575
        let prevMultiple5: CGFloat = 1100.0
        let nextMultiple5: CGFloat = 1100.0
        let result5 = getMultiples(adjustedHeight5)
        XCTAssertEqual(result5.0, prevMultiple5)
        XCTAssertEqual(result5.1, nextMultiple5)

        let adjustedHeight6: CGFloat = 925.0561051595749
        let prevMultiple6: CGFloat = 925.0
        let nextMultiple6: CGFloat = 925.0
        let result6 = getMultiples(adjustedHeight6)
        XCTAssertEqual(result6.0, prevMultiple6)
        XCTAssertEqual(result6.1, nextMultiple6)

    }

    func testNumberlineConstructionBasic() throws {

        let middle = 0.0

        let smallResult = constructNumberline(middle,
                                              stepCount: 3,
                                              stepScale: .small)
        let smallExpected = [0.3, 0.2, 0.1, 0.0, -0.1, -0.2, -0.3]
        XCTAssertEqual(smallResult, smallExpected)

        let normalResult = constructNumberline(middle,
                                               stepCount: 3,
                                               stepScale: .normal)
        let normalExpected = [3.0, 2.0, 1.0, 0.0, -1.0, -2.0, -3.0]

        XCTAssertEqual(normalResult, normalExpected)

        let largeResult = constructNumberline(middle,
                                              stepCount: 3,
                                              stepScale: .large)
        let largeExpected = [30.0, 20.0, 10.0, 0.0, -10.0, -20.0, -30.0]
        XCTAssertEqual(largeResult, largeExpected)
    }

    func testLargeNumberLine() throws {
        let middle = 0.0
        let smallResult2 = constructNumberline(middle,
                                               stepCount: 10,
                                               stepScale: .small)
        let smallExpected2 = [1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1, 0.0, -0.1, -0.2, -0.3, -0.4, -0.5, -0.6, -0.7, -0.8, -0.9, -1.0]

        // [1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1, -0.1, -0.2, -0.3, -0.4, -0.5, -0.6, -0.7, -0.8, -0.9, -1.0]
        XCTAssertEqual(smallResult2, smallExpected2)
    }

    // What happens if we have a large number, but use a .small scale?
    func testNumberlineConstructionNonZero() throws {

        let middle = 200.0

        let smallResult = constructNumberline(middle,
                                              stepCount: 3,
                                              stepScale: .small)
        let smallExpected = [200.3, 200.2, 200.1, 200.0, 199.9, 199.8, 199.7]
        XCTAssertEqual(smallResult, smallExpected)

        let normalResult = constructNumberline(middle,
                                               stepCount: 3,
                                               stepScale: .normal)
        let normalExpected = [203.0, 202.0, 201.0, 200.0, 199.0, 198.0, 197.0]
        XCTAssertEqual(normalResult, normalExpected)

        let largeResult = constructNumberline(middle,
                                              stepCount: 3,
                                              stepScale: .large)
        let largeExpected = [230.0, 220.0, 210.0, 200.0, 190.0, 180.0, 170.0]
        XCTAssertEqual(largeResult, largeExpected)
    }

    // is the problem ONLY when we
    func testNumberlineConstructionNegativeNumber() throws {

        let middle = -200.0

        let smallResult = constructNumberline(middle,
                                              stepCount: 3,
                                              stepScale: .small)
        let smallExpected = [-199.7, -199.8, -199.9, -200.0, -200.1, -200.2, -200.3]
        XCTAssertEqual(smallResult, smallExpected)

        let normalResult = constructNumberline(middle,
                                               stepCount: 3,
                                               stepScale: .normal)
        let normalExpected = [-197.0, -198.0, -199.0, -200.0, -201.0, -202.0, -203.0]
        XCTAssertEqual(normalResult, normalExpected)

        let largeResult = constructNumberline(middle,
                                              stepCount: 3,
                                              stepScale: .large)
        let largeExpected = [-170.0, -180.0, -190.0, -200.0, -210.0, -220.0, -230.0]
        XCTAssertEqual(largeResult, largeExpected)

    }

    // MARK: string coercison causes perf loss (GitHub issue #3120)
    //    func testDoubleToUserNumber() throws {
    //        XCTAssertEqual("2", 2.0.coerceToUserFriendlyString)
    //        XCTAssertEqual("0", 0.0.coerceToUserFriendlyString)
    //        XCTAssertEqual("20", 20.0.coerceToUserFriendlyString)
    //        XCTAssertEqual("2.2", 2.2.coerceToUserFriendlyString)
    //        XCTAssertEqual("20.2", 20.2.coerceToUserFriendlyString)
    //        XCTAssertEqual("20.02", 20.02.coerceToUserFriendlyString)
    //    }

    func testLinearAnimationUpward() throws {
        // goal:
        //        let toValue = 10

        // where we currently are
        // eg starts at 0
        //        let currentOutput = 0

        // holds current frame,
        // as well as animation-wide start and end,
        //        let animation = ClassicAnimationState()

        XCTAssertEqual(
            0.33,
            linearAnimation(
                t: 0.033, // ie 1/30
                b: 0,
                c: 10,
                d: 1))

        // ** linearAnimation: x: 0.66
        XCTAssertEqual(
            0.66,
            linearAnimation(
                t: 0.066, // 2/30
                b: 0,
                c: 10,
                d: 1))

        XCTAssertEqual(
            1,
            linearAnimation(
                t: 0.1, // 3/30
                b: 0,
                c: 10,
                d: 1))

        XCTAssertEqual(
            1.33,
            linearAnimation(
                t: 0.133,
                b: 0,
                c: 10,
                d: 1))
    }

    func testLinearAnimationDownward() throws {

        // goal is 0, start is 10
        // so diff for whole animation = -10
        // ie animate downwad

        let x1 = linearAnimation(
            t: 0.033,
            b: 10,
            c: -10,
            d: 1)

        XCTAssertEqual(9.67, x1)

        let x2 = linearAnimation(
            t: 0.066,
            b: 10,
            c: -10,
            d: 1)

        XCTAssertEqual(9.34, x2)

        let x3 = linearAnimation(
            t: 0.1,
            b: 10,
            c: -10,
            d: 1)

        XCTAssertEqual(9.0, x3)
    }

    // Understanding mod's behavior
    func testMod() {

        XCTAssertEqual(mod(9, 4), 1)
        XCTAssertEqual(2, mod(10, 4))

        XCTAssertEqual(0, mod(5, 5))
        XCTAssertEqual(1, mod(6, 5))

        XCTAssertEqual(0, mod(10, -2))
        XCTAssertEqual(0, mod(-10, -2))

        XCTAssertEqual(-1, mod(-10, 3))
        XCTAssertEqual(1, mod(10, -3))

        XCTAssertEqual(1.1, mod(10.1, -3))

        XCTAssertEqual(0, mod(10, 0))
    }

    func testRounded() {

        XCTAssertEqual(
            rounded(0.333, places: 2, roundUp: true),
            1)

        XCTAssertEqual(
            rounded(0.333, places: 2, roundUp: false),
            0.33)

    }

    func testProgressAndTransition() {

        XCTAssertEqual(75, transition(progress(75)))
        XCTAssertEqual(100, transition(progress(100)))
        XCTAssertEqual(200, transition(progress(200)))
        XCTAssertEqual(50, transition(progress(50)))
        XCTAssertEqual(0, transition(progress(0)))
        XCTAssertEqual(10, transition(progress(10)))
        XCTAssertEqual(20, transition(progress(20)))
        XCTAssertEqual(-20, transition(progress(-20)))
        XCTAssertEqual(-50, transition(progress(-50)))
        XCTAssertEqual(-5.0, transition(progress(-5.0)))
        XCTAssertEqual(75.5, transition(progress(75.5)))
    }

    func testProgressAndReverseProgress() {

        XCTAssertEqual(0.3, progress(30, start: 0, end: 100))
        XCTAssertEqual(0.7, reverseProgress(30, start: 0, end: 100))

        XCTAssertEqual(0.7, progress(70, start: 0, end: 100))
        XCTAssertEqual(0.3, reverseProgress(70, start: 0, end: 100))
    }
}
