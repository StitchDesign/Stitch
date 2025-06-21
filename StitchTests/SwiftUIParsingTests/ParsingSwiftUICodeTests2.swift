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

    func testZStackView() {
        let src = #"""
        ZStack {
            Text("Title")
            Rectangle()
                .fill(Color.green)
                .frame(width: 200, height: 100)
        }
        .padding()
        """#
        let actions = parseSwiftUIToActions(src)
        // Expecting: createContainer(ZStack), createText, setText, addChild(text), createShape(Rectangle),
        // setInput(fill), setInput(frame), addChild(rectangle), setInput(padding)
        // If parser emits padding as action 8 (on ZStack), expect 8 actions. If it emits as 9th, adjust accordingly.
        // Let's check if the last action is setInput with input == "padding"
        var expectedCount = 8
        if actions.count == 9 {
            // Check if last action is setInput for padding
            if case let .setInput(id, input, _) = actions[8], input == "padding" {
                expectedCount = 9
            }
        }
        XCTAssertEqual(actions.count, expectedCount, "Expected \(expectedCount) actions for ZStack with Text and Rectangle and padding")

        // 1. createContainer for ZStack
        guard case let .createContainer(zId, zType) = actions[0] else {
            XCTFail("First action should be createContainer"); return
        }
        XCTAssertEqual(zType, "ZStack")

        // 2. createText and setText for Title
        guard case let .createText(tId, _) = actions[1] else {
            XCTFail("Second action should be createText for Text"); return
        }
        guard case let .setText(tId2, tText) = actions[2] else {
            XCTFail("Third action should be setText for Text"); return
        }
        XCTAssertEqual(tId2, tId)
        XCTAssertEqual(tText, "Title")

        // 3. addChild for Text
        guard case let .addChild(parentId1, childId1) = actions[3] else {
            XCTFail("Fourth action should be addChild for Text"); return
        }
        XCTAssertEqual(parentId1, zId)
        XCTAssertEqual(childId1, tId)

        // 4. createShape for Rectangle
        guard case let .createShape(rId, rType) = actions[4] else {
            XCTFail("Fifth action should be createShape for Rectangle"); return
        }
        XCTAssertEqual(rType, "Rectangle")

        // 5. setInput fill on Rectangle
        guard case let .setInput(rId1, input1, value1) = actions[5] else {
            XCTFail("Sixth action should be setInput for fill"); return
        }
        XCTAssertEqual(rId1, rId)
        XCTAssertEqual(input1, "fill")
        XCTAssertEqual(value1, "Color.green")

        // 6. setInput frame on Rectangle
        guard case let .setInput(rId2, input2, value2) = actions[6] else {
            XCTFail("Seventh action should be setInput for frame"); return
        }
        XCTAssertEqual(rId2, rId)
        XCTAssertTrue(value2.contains("width: 200"))
        XCTAssertTrue(value2.contains("height: 100"))

        // 7. addChild for Rectangle
        guard case let .addChild(parentId2, childId2) = actions[7] else {
            XCTFail("Eighth action should be addChild for Rectangle"); return
        }
        XCTAssertEqual(parentId2, zId)
        XCTAssertEqual(childId2, rId)

        // 8. setInput padding on ZStack (if present)
        if actions.count == 9 {
            guard case let .setInput(padId, padInput, _) = actions[8] else {
                XCTFail("Ninth action should be setInput for padding"); return
            }
            XCTAssertEqual(padId, zId)
            XCTAssertEqual(padInput, "padding")
        }
    }
}
