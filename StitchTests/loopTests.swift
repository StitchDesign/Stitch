//
//  loopTests.swift
//  StitchTests
//
//  Created by Christian J Clampitt on 4/21/23.
//

import XCTest
@testable import Stitch

final class loopTests: XCTestCase {

    func testLoopInsertFriendlyIndices() throws {

        // for e.g. a loop like `[a, b, c]`
        let loopCount = 3

        XCTAssertEqual(getLoopInsertFriendlyIndices([-1], loopCount),
                       [3])
        XCTAssertEqual(getLoopInsertFriendlyIndices([-2], loopCount),
                       [2])
        XCTAssertEqual(getLoopInsertFriendlyIndices([-3], loopCount),
                       [1])
        XCTAssertEqual(getLoopInsertFriendlyIndices([-4], loopCount),
                       [0])
        XCTAssertEqual(getLoopInsertFriendlyIndices([-5], loopCount),
                       [3])
        XCTAssertEqual(getLoopInsertFriendlyIndices([-6], loopCount),
                       [2])
        XCTAssertEqual(getLoopInsertFriendlyIndices([-7], loopCount),
                       [1])

    }
}
