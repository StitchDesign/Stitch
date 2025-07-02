//
//  CodeToSyntaxToActionsTests.swift
//  StitchTests
//
//  Created by Christian J Clampitt on 7/2/25.
//

import XCTest
@testable import Stitch
import SwiftUICore

final class CodeToSyntaxToActionsTests: XCTestCase {
    
    func testVStackWithRectangle() throws {
        // Given
        let vstackExample = """
        VStack {
            Rectangle().fill(Color.blue)
        }
        """
        
        // When
        guard let syntaxView = SwiftUIViewVisitor.parseSwiftUICode(vstackExample) else {
            XCTFail("Failed to parse VStack example")
            return
        }
        
        // Then - Verify the root VStack
        XCTAssertEqual(syntaxView.name, .vStack)
        XCTAssertTrue(syntaxView.constructorArguments.isEmpty)
        XCTAssertTrue(syntaxView.modifiers.isEmpty)
        XCTAssertEqual(syntaxView.children.count, 1)
        
        // Verify the Rectangle child
        let rectangle = syntaxView.children[0]
        XCTAssertEqual(rectangle.name, .rectangle)
        XCTAssertTrue(rectangle.constructorArguments.isEmpty)
        XCTAssertEqual(rectangle.children.count, 0)
        
        // Verify the fill modifier on Rectangle
        XCTAssertEqual(rectangle.modifiers.count, 1)
        let fillModifier = rectangle.modifiers[0]
        XCTAssertEqual(fillModifier.name, .fill)
        XCTAssertEqual(fillModifier.arguments.count, 1)
        
        let argument = fillModifier.arguments[0]
        XCTAssertEqual(argument.label, .noLabel)
        
        // Verify the argument value is Color.blue
        if case let .simple(data) = argument.value {
            XCTAssertEqual(data.value, "Color.blue")
//            XCTAssertEqual(data.syntaxKind, .variable(.memberAccess))
            XCTAssertEqual(data.syntaxKind, .literal(.unknown))
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
        
        // When
        guard let syntaxView = SwiftUIViewVisitor.parseSwiftUICode(vstackExample) else {
            XCTFail("Failed to parse VStack example")
            return
        }
        
        let layerData = try syntaxView.deriveStitchActions()
        
        // Then - Verify the structure of the LayerData
        // 1. Check that we have exactly one root layer (the VStack)
        XCTAssertEqual(layerData.layers.count, 1)
        
        let vstackLayer = layerData.layers[0]
        
        // 2. Check that the VStack is a group with vertical orientation
        if case let .layer(layerType) = vstackLayer.node_name.value {
            XCTAssertEqual(layerType, .group)
        } else {
            XCTFail("Expected VStack to be a group layer")
        }
        
        // 3. Check that the VStack has one child (the Rectangle)
        XCTAssertEqual(vstackLayer.children?.count, 1)
        
        let rectangleLayer = vstackLayer.children![0]
        
        // 4. Check that the child is a rectangle
        if case let .layer(layerType) = rectangleLayer.node_name.value {
            XCTAssertEqual(layerType, .rectangle)
        } else {
            XCTFail("Expected child to be a rectangle layer")
        }
        
        // 5. Check that there are custom layer input values for the fill color
        let fillValues = layerData.custom_layer_input_values.filter { value in
            value.layer_input_coordinate.input_port_type.value == .color
        }
        
        XCTAssertEqual(fillValues.count, 1, "Expected exactly one fill color value")
        
        if let fillValue = fillValues.first {
            // The node ID should match the rectangle layer's ID
            XCTAssertEqual(fillValue.layer_input_coordinate.layer_id.value,
                           rectangleLayer.node_id.value)
            
            let blue: Color = ColorConversionUtils.hexToColor(Color.blue.asHexDisplay)!
            
            XCTAssertEqual(
                fillValue.value,
                .color(blue)
//                .color(.green) // fails, as it should
            )
            
            XCTAssertNotEqual(
                fillValue.value,
                .color(.green)
            )
        }
    }
}
