//
//  loopTests.swift
//  StitchTests
//
//  Created by Christian J Clampitt on 4/21/23.
//

import XCTest
@testable import Stitch
import SwiftyJSON

final class loopTests: XCTestCase {

    @MainActor var store = StitchStore()
    
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
    
    @MainActor
    func testJSONArray() throws {
        /*
         Old bug: JSONArray was adding its output to the list of inputs to turn into an array.
         Not caught by existing JSONArrayFromValues test because the bug came from `nodeViewModel.loopedEval` helper.
         */
        let document = StitchDocumentViewModel.createTestFriendlyDocument()
        if let node = document.nodeInserted(choice: .patch(.jsonArray)) {
            
            // How many inputs does the JSONArray node have?
            let inputCount = node.inputs.count
            let result: EvalResult = jsonArrayEval(node: node)
            
            // Result should be a JSON, with as many elements as there are are inputs
            if let arrayCount = result.outputsValues.first?.first?.getJSON?.array?.count {
                XCTAssertEqual(inputCount, arrayCount)
            } else {
                XCTFail("testJSONArray: No json array")
            }
        } else {
            XCTFail("testJSONArray: Could not create node")
        }
    }
} // loopTests
