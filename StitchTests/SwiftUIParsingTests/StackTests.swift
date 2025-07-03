//
//  StackTests.swift
//  StitchTests
//
//  Created by Christian J Clampitt on 7/2/25.
//

import XCTest
@testable import Stitch
import SwiftUICore


final class StackTests: XCTestCase {

    func testVStackWithRectangle() throws {
        // Given
        let vstackExample = """
        VStack {
            Rectangle().fill(Color.blue)
        }
        """
        
        let syntaxView = getSyntaxView(vstackExample)
        
        // Then - Verify the root VStack
        XCTAssertEqual(syntaxView.name, .vStack)
        XCTAssertNotEqual(syntaxView.name, .hStack, "Should be a VStack, not HStack")
        XCTAssertTrue(syntaxView.constructorArguments.isEmpty, "VStack should have no constructor arguments")
        XCTAssertTrue(syntaxView.modifiers.isEmpty, "VStack should have no modifiers")
        XCTAssertEqual(syntaxView.children.count, 1, "VStack should have exactly one child")
        
        // Verify the Rectangle child
        let rectangle = syntaxView.children[0]
        XCTAssertEqual(rectangle.name, .rectangle, "Child should be a Rectangle")
        XCTAssertNotEqual(rectangle.name, .circle, "Child should not be a Circle")
        XCTAssertTrue(rectangle.constructorArguments.isEmpty, "Rectangle should have no constructor arguments")
        XCTAssertEqual(rectangle.children.count, 0, "Rectangle should have no children")
        
        // Verify the fill modifier on Rectangle
        XCTAssertEqual(rectangle.modifiers.count, 1, "Rectangle should have one modifier")
        
        let fillModifier = rectangle.modifiers[0]
        XCTAssertEqual(fillModifier.name, .fill, "Modifier should be a fill modifier")
        
        XCTAssertEqual(fillModifier.arguments.count, 1, "Fill modifier should have one argument")
        
        let argument = fillModifier.arguments[0]
        XCTAssertEqual(argument.label, .noLabel, "Fill argument should have no label")
        
        // Verify the argument value is Color.blue
        // TODO: come back here after exploring decoding
        if case let .simple(data) = argument.value {
            XCTAssertEqual(data.value, "Color.blue", "Color should be blue")
            
            // Check the syntax kind
//            XCTAssertEqual(data.syntaxKind, .literal(.unknown), "Color syntax kind should be unknown literal")
//            XCTAssertNotEqual(data.syntaxKind, .literal(.integer), "Color should not be an integer")
        } else {
            XCTFail("Expected simple argument value")
        }
    }
    
    func testVStackWithRectangleToLayerData() throws {
        // Given
        let vstackExample = """
        VStack {
            Rectangle().fill(Color.blue)
        }
        """
        

        let syntaxView = getSyntaxView(vstackExample)

        let layerData = syntaxView.getFirstSyntaxAction()
        
        // Then - Verify the structure of the LayerData
        // 1. Check that we have exactly one root layer (the VStack)
        let vstackLayer = layerData
        
        // 2. Check that the VStack is a group with vertical orientation
        if case let .layer(layerType) = vstackLayer.node_name.value {
            XCTAssertEqual(layerType, .group, "VStack should be a group layer")
        } else {
            XCTFail("Expected VStack to be a group layer")
        }
        
        // 3. Check that the VStack has one child (the Rectangle)
        guard let children = vstackLayer.children else {
            XCTFail("VStack should have children")
            return
        }
        
        XCTAssertEqual(children.count, 1, "VStack should have exactly one child")
        
        let rectangleLayer = children[0]
        
        // 4. Check that the child is a rectangle
        if case let .layer(layerType) = rectangleLayer.node_name.value {
            XCTAssertEqual(layerType, .rectangle, "Child should be a rectangle")
        } else {
            XCTFail("Expected child to be a rectangle layer")
        }
        
        // 5. Check that there are custom layer input values for the fill color
        let fillValues = rectangleLayer.custom_layer_input_values.filter { value in
            value.layer_input_coordinate.input_port_type.value == .color
        }
                        
        XCTAssertEqual(fillValues.count, 1, "Expected exactly one fill color value")
        
        if let fillValue = fillValues.first {
            // The node ID should match the rectangle layer's ID
            XCTAssertEqual(
                fillValue.layer_input_coordinate.layer_id.value,
                rectangleLayer.node_id.value,
                "Fill value should be associated with the rectangle layer"
            )
            
            // Verify it's not associated with the VStack layer
            XCTAssertNotEqual(
                fillValue.layer_input_coordinate.layer_id.value,
                vstackLayer.node_id.value,
                "Fill value should not be associated with the VStack layer"
            )
            
            let blue: Color = ColorConversionUtils.hexToColor(Color.blue.asHexDisplay)!
            let red: Color = ColorConversionUtils.hexToColor(Color.red.asHexDisplay)!
            
            // Test positive case
            XCTAssertEqual(
                fillValue.value,
                .color(blue),
                "Fill color should be blue"
            )
            
            // Test negative cases
            XCTAssertNotEqual(
                fillValue.value,
                .color(red),
                "Fill color should not be red"
            )
            
            // Test with explicit .color case
            if case let .color(fillColor) = fillValue.value {
                XCTAssertEqual(fillColor, blue, "Fill color should be blue")
                XCTAssertNotEqual(fillColor, red, "Fill color should not be red")
            } else {
                XCTFail("Expected a color value")
            }
        }
    }
    

}
