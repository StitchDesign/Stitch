//
//  VPLSyntaxTest.swift
//  StitchTests
//
//  Created by Christian J Clampitt on 6/22/25.
//

import XCTest

//final class SwiftUIViewParserTests: XCTestCase {
//
//    func testSimpleTextView() throws {
//        let code = "Text(\"salut\")"
//        let node = try parseSwiftUIView(code: code)
//        XCTAssertEqual(node.name, "Text")
//        XCTAssertEqual(node.arguments.first?.value, "\"salut\"")
//    }
//
//    func testRectangleWithModifier() throws {
//        let code = "Rectangle().frame(width: 200, height: 100)"
//        let node = try parseSwiftUIView(code: code)
//        XCTAssertEqual(node.name, "Rectangle")
//        XCTAssertEqual(node.modifiers.first?.name, "frame")
//        XCTAssertEqual(node.modifiers.first?.arguments.count, 2)
//    }
//
//    func testNestedViews() throws {
//        let code = """
//        ZStack {
//            Rectangle().fill(Color.blue)
//            VStack {
//                Rectangle().fill(Color.green)
//                Rectangle().fill(Color.red)
//            }
//        }
//        """
//        let node = try parseSwiftUIView(code: code)
//        XCTAssertEqual(node.name, "Closure")
//        XCTAssertEqual(node.children.count, 1)  // "Closure" wraps the ZStack
//        let zstack = node.children[0]
//        XCTAssertEqual(zstack.name, "ZStack")
//    }
//}
