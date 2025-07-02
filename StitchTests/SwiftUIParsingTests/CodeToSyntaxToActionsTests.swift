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
    
    func testRectangleWithPositionToLayerData() throws {
        // Given
        let code = """
        Rectangle()
            .position(x: 200, y: 200)
        """
        
        // When - Parse the SwiftUI code into a SyntaxView
        guard let syntaxView = SwiftUIViewVisitor.parseSwiftUICode(code) else {
            XCTFail("Failed to parse Rectangle with position example")
            return
        }
        
        // Then - Verify the SyntaxView structure
        // 1. Check the root view is a Rectangle
        XCTAssertEqual(syntaxView.name, .rectangle, "Root view should be a Rectangle")
        XCTAssertTrue(syntaxView.constructorArguments.isEmpty, "Rectangle should have no constructor arguments")
        
        // 2. Verify the position modifier
        XCTAssertEqual(syntaxView.modifiers.count, 1, "Should have one modifier (position)")
        let positionModifier = syntaxView.modifiers[0]
        XCTAssertEqual(positionModifier.name, .position, "Modifier should be a position modifier")
        
        // 3. Check position arguments (x and y)
        XCTAssertEqual(positionModifier.arguments.count, 2, "Position modifier should have two arguments (x and y)")
        
        // Verify x argument
        if let xArg = positionModifier.arguments.first(where: { $0.label == .x }),
           case let .simple(xData) = xArg.value {
            XCTAssertEqual(xData.value, "200", "X position should be 200")
        } else {
            XCTFail("Could not find or validate x position argument")
        }
        
        // Verify y argument
        if let yArg = positionModifier.arguments.first(where: { $0.label == .y }),
           case let .simple(yData) = yArg.value {
            XCTAssertEqual(yData.value, "200", "Y position should be 200")
        } else {
            XCTFail("Could not find or validate y position argument")
        }
        
        // When - Convert to LayerData
        let layerData = try syntaxView.deriveStitchActions()
        
        // Then - Verify the structure of the LayerData
        // 1. Check that we have exactly one root layer (the Rectangle)
        XCTAssertEqual(layerData.layers.count, 1, "Should have exactly one layer")
        
        let rectangleLayer = layerData.layers[0]
        
        // 2. Check that the layer is a rectangle
        if case let .layer(layerType) = rectangleLayer.node_name.value {
            XCTAssertEqual(layerType, .rectangle, "Layer type should be rectangle")
        } else {
            XCTFail("Expected root layer to be a rectangle")
        }
        
        // 3. Verify position values in LayerData
        let positionValues = layerData.custom_layer_input_values.filter { value in
            value.layer_input_coordinate.input_port_type.value == .position
        }
        
        // 4. Verify we have exactly one position value (combining x and y)
        XCTAssertEqual(positionValues.count, 1, "Should have exactly one position value")
        
        let positionValue = positionValues.first!
        let positionPortValue = positionValue.value
        if case .position(let p) = positionPortValue {
            XCTAssertEqual(p, CGPoint(x: 200, y: 200), "Position should be (200, 200)")
            XCTAssertNotEqual(p, CGPoint(x: 200, y: 50), "Position should be (200, 200)")
        } else {
            XCTFail("Expected position value to be a CGPoint")
        }
        
        // 5. Verify the layer IDs match between the layer and its custom values
        let layerId = rectangleLayer.node_id.value
        XCTAssertEqual(
            positionValue.layer_input_coordinate.layer_id.value,
            layerId,
            "Position value should be associated with the rectangle layer"
        )
    }
    
    func testRoundedRectangleWithCornerRadius() throws {
        // Given
        let code = """
        RoundedRectangle(cornerRadius: 25)
        """
        
        // When - Parse the SwiftUI code into a SyntaxView
        guard let syntaxView = SwiftUIViewVisitor.parseSwiftUICode(code) else {
            XCTFail("Failed to parse RoundedRectangle example")
            return
        }
        
        // Then - Verify the SyntaxView structure
        // 1. Check the root view is a RoundedRectangle
        XCTAssertEqual(syntaxView.name, .roundedRectangle, "Root view should be a RoundedRectangle")
        XCTAssertNotEqual(syntaxView.name, .rectangle, "RoundedRectangle should not be a plain Rectangle")
        XCTAssertEqual(syntaxView.modifiers.count, 0, "RoundedRectangle should have no modifiers")
        XCTAssertNotEqual(syntaxView.modifiers.count, 1, "RoundedRectangle should not have any modifiers")
        XCTAssertEqual(syntaxView.children.count, 0, "RoundedRectangle should have no children")
        
        // 2. Verify the constructor arguments
        XCTAssertEqual(syntaxView.constructorArguments.count, 1, "RoundedRectangle should have one constructor argument (cornerRadius)")
        XCTAssertNotEqual(syntaxView.constructorArguments.count, 0, "RoundedRectangle should have constructor arguments")
        XCTAssertNotEqual(syntaxView.constructorArguments.count, 2, "RoundedRectangle should not have multiple constructor arguments")
        
        // 3. Check the cornerRadius argument
        let cornerRadiusArg = syntaxView.constructorArguments[0]
        XCTAssertEqual(cornerRadiusArg.label, .cornerRadius, "Constructor argument should be 'cornerRadius'")
        XCTAssertNotEqual(cornerRadiusArg.label, .systemName, "Constructor argument should not be 'systemName'")
        
        // 4. Verify the corner radius value is 25 with correct syntax kind
        XCTAssertEqual(cornerRadiusArg.values.count, 1, "cornerRadius should have one value")
        XCTAssertNotEqual(cornerRadiusArg.values.count, 0, "cornerRadius should not be empty")
        XCTAssertNotEqual(cornerRadiusArg.values.count, 2, "cornerRadius should not have multiple values")
        
        let value = cornerRadiusArg.values[0]
        XCTAssertEqual(value.value, "25", "Corner radius value should be '25'")
        XCTAssertNotEqual(value.value, "24", "Corner radius value should not be '24'")
        XCTAssertNotEqual(value.value, "26", "Corner radius value should not be '26'")
        
        XCTAssertEqual(value.syntaxKind, .literal(.integer), "Corner radius should be an integer literal")
        XCTAssertNotEqual(value.syntaxKind, .literal(.float), "Corner radius should not be a floating point")
        XCTAssertNotEqual(value.syntaxKind, .literal(.string), "Corner radius should not be a string")
        
        // When - Convert to LayerData
        let layerData = try syntaxView.deriveStitchActions()
        
        // Then - Verify the structure of the LayerData
        // 1. Check that we have exactly one root layer (the RoundedRectangle)
        XCTAssertEqual(layerData.layers.count, 1, "Should have exactly one layer")
        XCTAssertNotEqual(layerData.layers.count, 0, "Should have at least one layer")
        XCTAssertNotEqual(layerData.layers.count, 2, "Should not have multiple layers")
        
        let roundedRectLayer = layerData.layers[0]
        
        // 2. Check that it's a rectangle layer (RoundedRectangle maps to .rectangle with cornerRadius input)
        if case let .layer(layerType) = roundedRectLayer.node_name.value {
            XCTAssertEqual(layerType, .rectangle, "RoundedRectangle should map to .rectangle layer type")
            XCTAssertNotEqual(layerType, .oval, "RoundedRectangle should not map to .oval")
        } else {
            XCTFail("Expected a rectangle layer")
        }
        
        // 3. Check that there are custom layer input values for the corner radius
        XCTAssertFalse(layerData.custom_layer_input_values.isEmpty, "Expected custom_layer_input_values for corner radius")
        XCTAssertNotEqual(layerData.custom_layer_input_values.count, 0, "Should have at least one custom layer input value")
        
        // 4. Find the corner radius input for this layer
        let layerId = roundedRectLayer.node_id.value
        let cornerRadiusInputs = layerData.custom_layer_input_values.filter { input in
            input.layer_input_coordinate.layer_id.value == layerId &&
            input.layer_input_coordinate.input_port_type.value == .cornerRadius
        }
        
        XCTAssertEqual(cornerRadiusInputs.count, 1, "Expected exactly one corner radius input")
        XCTAssertNotEqual(cornerRadiusInputs.count, 0, "Should have at least one corner radius input")
        XCTAssertNotEqual(cornerRadiusInputs.count, 2, "Should not have multiple corner radius inputs")
        
        let cornerRadiusInput = cornerRadiusInputs[0]
        
        // 5. Verify the corner radius value is 25
        if case let .number(value) = cornerRadiusInput.value {
            XCTAssertEqual(value, 25, "Expected corner radius to be 25")
            XCTAssertNotEqual(value, 24, "Corner radius should not be 24")
            XCTAssertNotEqual(value, 26, "Corner radius should not be 26")
            
            // Check type is exactly Double
            XCTAssertTrue(type(of: value) == Double.self, "Corner radius should be a Double")
        } else {
            XCTFail("Expected corner radius to be a number value")
            
            // Additional type checking that should fail if we get here
            if let value = cornerRadiusInput.value as? String {
                XCTFail("Corner radius should not be a string: \(value)")
            } else if let value = cornerRadiusInput.value as? Bool {
                XCTFail("Corner radius should not be a boolean: \(value)")
            }
        }
        
        // 6. Verify no other unexpected input types exist for this layer
        let otherInputs = layerData.custom_layer_input_values.filter { input in
            input.layer_input_coordinate.layer_id.value == layerId &&
            input.layer_input_coordinate.input_port_type.value != .cornerRadius
        }
        
        XCTAssertTrue(otherInputs.isEmpty, "Should not have any other input types for this layer")
        
        // 7. Verify the layer name is not empty
        XCTAssertFalse(roundedRectLayer.node_name.value.description.isEmpty, "Layer should have a name")
    }
    
    func testRectangleWithOffsetToLayerData() throws {
        // Given
        let code = """
        Rectangle()
            .offset(x: 200, y: 200)
        """
        
        // When - Parse the SwiftUI code into a SyntaxView
        guard let syntaxView = SwiftUIViewVisitor.parseSwiftUICode(code) else {
            XCTFail("Failed to parse Rectangle with offset example")
            return
        }
        
        // Then - Verify the SyntaxView structure
        // 1. Check the root view is a Rectangle
        XCTAssertEqual(syntaxView.name, .rectangle, "Root view should be a Rectangle")
        XCTAssertTrue(syntaxView.constructorArguments.isEmpty, "Rectangle should have no constructor arguments")
        
        // 2. Verify the offset modifier
        XCTAssertEqual(syntaxView.modifiers.count, 1, "Should have one modifier (offset)")
        let offsetModifier = syntaxView.modifiers[0]
        XCTAssertEqual(offsetModifier.name, .offset, "Modifier should be an offset modifier")
        
        // 3. Check offset arguments (x and y)
        XCTAssertEqual(offsetModifier.arguments.count, 2, "Offset modifier should have two arguments (x and y)")
        
        // Verify x argument
        if let xArg = offsetModifier.arguments.first(where: { $0.label == .x }),
           case let .simple(xData) = xArg.value {
            XCTAssertEqual(xData.value, "200", "X offset should be 200")
        } else {
            XCTFail("Could not find or validate x offset argument")
        }
        
        // Verify y argument
        if let yArg = offsetModifier.arguments.first(where: { $0.label == .y }),
           case let .simple(yData) = yArg.value {
            XCTAssertEqual(yData.value, "200", "Y offset should be 200")
        } else {
            XCTFail("Could not find or validate y offset argument")
        }
        
        // When - Convert to LayerData
        let layerData = try syntaxView.deriveStitchActions()
        
        // Then - Verify the structure of the LayerData
        // 1. Check that we have exactly one root layer (the Rectangle)
        XCTAssertEqual(layerData.layers.count, 1, "Should have exactly one layer")
        
        let rectangleLayer = layerData.layers[0]
        
        // 2. Check that the layer is a rectangle
        if case let .layer(layerType) = rectangleLayer.node_name.value {
            XCTAssertEqual(layerType, .rectangle, "Layer type should be rectangle")
        } else {
            XCTFail("Expected root layer to be a rectangle")
        }
        
        // 3. Verify offset values in LayerData
        // Note: Based on the example, offset is also represented as a position in the custom values
        let offsetValues = layerData.custom_layer_input_values.filter { value in
            value.layer_input_coordinate.input_port_type.value == .position
        }
        
        // 4. Verify we have exactly one position value (combining x and y offset)
        XCTAssertEqual(offsetValues.count, 1, "Should have exactly one position value for offset")
        
        let offsetValue = offsetValues.first!
        let offsetPortValue = offsetValue.value
        if case .position(let p) = offsetPortValue {
            XCTAssertEqual(p, CGPoint(x: 200, y: 200), "Offset should be (200, 200)")
        } else {
            XCTFail("Expected offset value to be a CGPoint")
        }
        
        // 5. Verify the layer IDs match between the layer and its custom values
        let layerId = rectangleLayer.node_id.value
        XCTAssertEqual(
            offsetValue.layer_input_coordinate.layer_id.value,
            layerId,
            "Offset value should be associated with the rectangle layer"
        )
    }
}
