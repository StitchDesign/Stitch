//
//  ParsingSwiftUICodeTests.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/20/25.
//


import XCTest
@testable import Stitch

//final class ParsingSwiftUICodeTests: XCTestCase {
//
//    func testSimpleRectangle() {
//        let code = """
//        Rectangle()
//            .fill(Color.blue)
//            .opacity(0.5)
//        """
//        let actions = parseSwiftUICodeToActions(code)
//        
//        XCTAssertEqual(actions.count, 3, "Expected 3 actions for Rectangle with fill and opacity")
//        
//        // 1. AddNode for Rectangle
//        guard let addNode = actions[0] as? StepActionAddNode else {
//            XCTFail("First action should be StepActionAddNode"); return
//        }
//        if case .layer(.rectangle) = addNode.nodeName {
//            // OK
//        } else {
//            XCTFail("Expected rectangle layer in StepActionAddNode")
//        }
//        
//        // 2. SetInput for fill color
//        guard let setFill = actions[1] as? StepActionSetInput else {
//            XCTFail("Second action should be StepActionSetInput for fill"); return
//        }
//        XCTAssertEqual(setFill.value, .color(.blue), "Expected fill color blue")
//        XCTAssertEqual(setFill.port.keyPath!.layerInput, LayerInputPort.color, "Expected color port")
//        
//        // 3. SetInput for opacity
//        guard let setOpacity = actions[2] as? StepActionSetInput else {
//            XCTFail("Third action should be StepActionSetInput for opacity"); return
//        }
//        XCTAssertEqual(setOpacity.value, .number(0.5), "Expected opacity 0.5")
//        XCTAssertEqual(setOpacity.port.keyPath!.layerInput, LayerInputPort.opacity, "Expected opacity port")
//    }
//
//    func testTextView() {
//        let code = """
//        Text("Hello, World!")
//            .foregroundColor(.red)
//        """
//        let actions = parseSwiftUICodeToActions(code)
//        
//        XCTAssertEqual(actions.count, 3, "Expected 3 actions for Text with content and color")
//        
//        // 1. AddNode for Text
//        guard let addNode = actions[0] as? StepActionAddNode else {
//            XCTFail("First action should be StepActionAddNode"); return
//        }
//        if case .layer(.text) = addNode.nodeName {
//            // OK
//        } else {
//            XCTFail("Expected text layer in StepActionAddNode")
//        }
//        
//        // 2. SetInput for text content
//        guard let setText = actions[1] as? StepActionSetInput else {
//            XCTFail("Second action should be StepActionSetInput for text content"); return
//        }
//        XCTAssertEqual(setText.value, .string(.init("Hello, World!")), "Expected text content Hello, World!")
//        XCTAssertEqual(setText.port.keyPath!.layerInput, LayerInputPort.text, "Expected text port")
//        
//        // 3. SetInput for foregroundColor
//        guard let setColor = actions[2] as? StepActionSetInput else {
//            XCTFail("Third action should be StepActionSetInput for color"); return
//        }
//        XCTAssertEqual(setColor.value, .color(.red), "Expected color red")
//        XCTAssertEqual(setColor.port.keyPath!.layerInput, LayerInputPort.color, "Expected color port")
//    }
//}
