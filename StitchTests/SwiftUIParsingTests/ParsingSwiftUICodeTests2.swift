//
//  ParsingSwiftUICodeTests2.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/20/25.
//


//
//  ParsingSwiftUICodeTests2.swift
//  StitchTests
//
//  Created by Christian J Clampitt on 6/20/25.
//

import XCTest
@testable import Stitch

final class ParsingSwiftUICodeTests: XCTestCase {

    func testSimpleRectangle() {
        let src = #"""
        Rectangle()
            .fill(Color.blue)
            .opacity(0.5)
        """#
        let actions = parseSwiftUIToActions(src)
        XCTAssertEqual(actions.count, 3, "Expected 3 actions for Rectangle with fill and opacity")

        // 1. createShape Rectangle
        guard case let .createShape(id, type) = actions[0] else {
            XCTFail("First action should be createShape"); return
        }
        XCTAssertEqual(type, "Rectangle")

        // 2. setInput fill
        guard case let .setInput(id1, input1, value1) = actions[1] else {
            XCTFail("Second action should be setInput for fill"); return
        }
        XCTAssertEqual(id1, id)
        XCTAssertEqual(input1, "fill")
        XCTAssertEqual(value1, "Color.blue")

        // 3. setInput opacity
        guard case let .setInput(_, input2, value2) = actions[2] else {
            XCTFail("Third action should be setInput for opacity"); return
        }
        XCTAssertEqual(input2, "opacity")
        XCTAssertEqual(value2, "0.5")
    }

    func testTextView() {
        let src = #"""
        Text("Hello, World!")
            .foregroundColor(.red)
        """#
        let actions = parseSwiftUIToActions(src)
        XCTAssertEqual(actions.count, 3, "Expected 3 actions for Text with content and color")

        // 1. createText
        guard case let .createText(id, _) = actions[0] else {
            XCTFail("First action should be createText"); return
        }

        // 2. setText
        guard case let .setText(id1, text) = actions[1] else {
            XCTFail("Second action should be setText"); return
        }
        XCTAssertEqual(id1, id)
        XCTAssertEqual(text, "Hello, World!")

        // 3. setInput foregroundColor
        guard case let .setInput(_, input, value) = actions[2] else {
            XCTFail("Third action should be setInput for color"); return
        }
        XCTAssertEqual(input, "foregroundColor")
        XCTAssertEqual(value, ".red")
    }
}
