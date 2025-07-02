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
        XCTAssertNotEqual(syntaxView.name, .hStack, "Should be a VStack, not HStack")
        XCTAssertTrue(syntaxView.constructorArguments.isEmpty, "VStack should have no constructor arguments")
        XCTAssertTrue(syntaxView.modifiers.isEmpty, "VStack should have no modifiers")
        XCTAssertEqual(syntaxView.children.count, 1, "VStack should have exactly one child")
        XCTAssertNotEqual(syntaxView.children.count, 0, "VStack should have children")
        XCTAssertNotEqual(syntaxView.children.count, 2, "VStack should have only one child in this test")
        
        // Verify the Rectangle child
        let rectangle = syntaxView.children[0]
        XCTAssertEqual(rectangle.name, .rectangle, "Child should be a Rectangle")
        XCTAssertNotEqual(rectangle.name, .circle, "Child should not be a Circle")
        XCTAssertTrue(rectangle.constructorArguments.isEmpty, "Rectangle should have no constructor arguments")
        XCTAssertEqual(rectangle.children.count, 0, "Rectangle should have no children")
        
        // Verify the fill modifier on Rectangle
        XCTAssertEqual(rectangle.modifiers.count, 1, "Rectangle should have one modifier")
        XCTAssertNotEqual(rectangle.modifiers.count, 0, "Rectangle should have a fill modifier")
        XCTAssertNotEqual(rectangle.modifiers.count, 2, "Rectangle should have only one modifier")
        
        let fillModifier = rectangle.modifiers[0]
        XCTAssertEqual(fillModifier.name, .fill, "Modifier should be a fill modifier")
        XCTAssertNotEqual(fillModifier.name, .frame, "Modifier should not be a frame modifier")
        
        XCTAssertEqual(fillModifier.arguments.count, 1, "Fill modifier should have one argument")
        XCTAssertNotEqual(fillModifier.arguments.count, 0, "Fill modifier should have arguments")
        
        let argument = fillModifier.arguments[0]
        XCTAssertEqual(argument.label, .noLabel, "Fill argument should have no label")
        
        // Verify the argument value is Color.blue
        if case let .simple(data) = argument.value {
            XCTAssertEqual(data.value, "Color.blue", "Color should be blue")
            XCTAssertNotEqual(data.value, "Color.red", "Color should not be red")
            XCTAssertNotEqual(data.value, "blue", "Color should be fully qualified")
            
            // Check the syntax kind
            XCTAssertEqual(data.syntaxKind, .literal(.unknown), "Color syntax kind should be unknown literal")
            XCTAssertNotEqual(data.syntaxKind, .literal(.integer), "Color should not be an integer")
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
        XCTAssertEqual(layerData.layers.count, 1, "Should have exactly one root layer")
        XCTAssertNotEqual(layerData.layers.count, 0, "Should have at least one layer")
        XCTAssertNotEqual(layerData.layers.count, 2, "Should not have multiple root layers")
        
        let vstackLayer = layerData.layers[0]
        
        // 2. Check that the VStack is a group with vertical orientation
        if case let .layer(layerType) = vstackLayer.node_name.value {
            XCTAssertEqual(layerType, .group, "VStack should be a group layer")
            XCTAssertNotEqual(layerType, .rectangle, "VStack should not be a rectangle")
        } else {
            XCTFail("Expected VStack to be a group layer")
        }
        
        // 3. Check that the VStack has one child (the Rectangle)
        guard let children = vstackLayer.children else {
            XCTFail("VStack should have children")
            return
        }
        
        XCTAssertEqual(children.count, 1, "VStack should have exactly one child")
        XCTAssertNotEqual(children.count, 0, "VStack should have children")
        
        let rectangleLayer = children[0]
        
        // 4. Check that the child is a rectangle
        if case let .layer(layerType) = rectangleLayer.node_name.value {
            XCTAssertEqual(layerType, .rectangle, "Child should be a rectangle")
            XCTAssertNotEqual(layerType, .oval, "Child should not be a oval")
            XCTAssertNotEqual(layerType, .group, "Child should not be a group")
        } else {
            XCTFail("Expected child to be a rectangle layer")
        }
        
        // 5. Check that there are custom layer input values for the fill color
        let fillValues = layerData.custom_layer_input_values.filter { value in
            value.layer_input_coordinate.input_port_type.value == .color
        }
        
        XCTAssertEqual(fillValues.count, 1, "Expected exactly one fill color value")
        XCTAssertNotEqual(fillValues.count, 0, "Should have at least one fill color")
        XCTAssertNotEqual(fillValues.count, 2, "Should not have multiple fill colors")
        
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
        XCTAssertNotEqual(syntaxView.name, .roundedRectangle, "Should be a plain Rectangle, not RoundedRectangle")
        XCTAssertTrue(syntaxView.constructorArguments.isEmpty, "Rectangle should have no constructor arguments")
        
        // 2. Verify the position modifier
        XCTAssertEqual(syntaxView.modifiers.count, 1, "Should have one modifier (position)")
        XCTAssertNotEqual(syntaxView.modifiers.count, 0, "Should have a position modifier")
        XCTAssertNotEqual(syntaxView.modifiers.count, 2, "Should have only one modifier")
        
        let positionModifier = syntaxView.modifiers[0]
        XCTAssertEqual(positionModifier.name, .position, "Modifier should be a position modifier")
        XCTAssertNotEqual(positionModifier.name, .offset, "Modifier should not be an offset modifier")
        
        // 3. Check position arguments (x and y)
        XCTAssertEqual(positionModifier.arguments.count, 2, "Position modifier should have two arguments (x and y)")
        XCTAssertNotEqual(positionModifier.arguments.count, 1, "Position should have both x and y arguments")
        
        // Verify x argument
        if let xArg = positionModifier.arguments.first(where: { $0.label == .x }),
           case let .simple(xData) = xArg.value {
            XCTAssertEqual(xData.value, "200", "X position should be 200")
            XCTAssertNotEqual(xData.value, "100", "X position should not be 100")
            XCTAssertEqual(xData.syntaxKind, .literal(.integer), "X position should be an integer")
        } else {
            XCTFail("Could not find or validate x position argument")
        }
        
        // Verify y argument
        if let yArg = positionModifier.arguments.first(where: { $0.label == .y }),
           case let .simple(yData) = yArg.value {
            XCTAssertEqual(yData.value, "200", "Y position should be 200")
            XCTAssertNotEqual(yData.value, "100", "Y position should not be 100")
            XCTAssertEqual(yData.syntaxKind, .literal(.integer), "Y position should be an integer")
        } else {
            XCTFail("Could not find or validate y position argument")
        }
        
        // When - Convert to LayerData
        let layerData = try syntaxView.deriveStitchActions()
        
        // Then - Verify the structure of the LayerData
        // 1. Check that we have exactly one root layer (the Rectangle)
        XCTAssertEqual(layerData.layers.count, 1, "Should have exactly one layer")
        XCTAssertNotEqual(layerData.layers.count, 0, "Should have at least one layer")
        XCTAssertNotEqual(layerData.layers.count, 2, "Should not have multiple layers")
        
        let rectangleLayer = layerData.layers[0]
        
        // 2. Check that the layer is a rectangle
        if case let .layer(layerType) = rectangleLayer.node_name.value {
            XCTAssertEqual(layerType, .rectangle, "Layer type should be rectangle")
            XCTAssertNotEqual(layerType, .oval, "Layer should not be a oval")
        } else {
            XCTFail("Expected root layer to be a rectangle")
        }
        
        // 3. Verify position values in LayerData
        let positionValues = layerData.custom_layer_input_values.filter { value in
            value.layer_input_coordinate.input_port_type.value == .position
        }
        
        // 4. Verify we have exactly one position value (combining x and y)
        XCTAssertEqual(positionValues.count, 1, "Should have exactly one position value")
        XCTAssertNotEqual(positionValues.count, 0, "Should have a position value")
        XCTAssertNotEqual(positionValues.count, 2, "Should not have multiple position values")
        
        let positionValue = positionValues.first!
        let positionPortValue = positionValue.value
        
        // Verify the position is associated with the correct layer
        XCTAssertEqual(
            positionValue.layer_input_coordinate.layer_id.value,
            rectangleLayer.node_id.value,
            "Position should be associated with the rectangle layer"
        )
        
        if case .position(let p) = positionPortValue {
            // Test exact position
            XCTAssertEqual(p, CGPoint(x: 200, y: 200), "Position should be (200, 200)")
            
            // Test incorrect positions
            XCTAssertNotEqual(p, CGPoint(x: 200, y: 50), "Y position should be 200, not 50")
            XCTAssertNotEqual(p, CGPoint(x: 100, y: 200), "X position should be 200, not 100")
            XCTAssertNotEqual(p, CGPoint(x: 0, y: 0), "Position should not be at origin")
            
            // Test individual components
            XCTAssertEqual(p.x, 200, "X coordinate should be 200")
            XCTAssertEqual(p.y, 200, "Y coordinate should be 200")
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
    
    func testRectangleWithFrame() throws {
        // Given
        let code = """
        Rectangle()
            .frame(width: 200, height: 100)
        """
        
        // When - Parse the SwiftUI code into a SyntaxView
        guard let syntaxView = SwiftUIViewVisitor.parseSwiftUICode(code) else {
            XCTFail("Failed to parse Rectangle with frame example")
            return
        }
        
        // Then - Verify the SyntaxView structure
        // 1. Check the root view is a Rectangle
        XCTAssertEqual(syntaxView.name, .rectangle, "Root view should be a Rectangle")
        XCTAssertNotEqual(syntaxView.name, .roundedRectangle, "Should be a plain Rectangle, not RoundedRectangle")
        XCTAssertTrue(syntaxView.constructorArguments.isEmpty, "Rectangle should have no constructor arguments")
        
        // 2. Verify the frame modifier
        XCTAssertEqual(syntaxView.modifiers.count, 1, "Should have one modifier (frame)")
        XCTAssertNotEqual(syntaxView.modifiers.count, 0, "Should have a frame modifier")
        XCTAssertNotEqual(syntaxView.modifiers.count, 2, "Should have only one modifier")
        
        let frameModifier = syntaxView.modifiers[0]
        XCTAssertEqual(frameModifier.name, .frame, "Modifier should be a frame modifier")
        XCTAssertNotEqual(frameModifier.name, .position, "Modifier should not be a position modifier")
        
        // 3. Check frame arguments (width and height)
        XCTAssertEqual(frameModifier.arguments.count, 2, "Frame modifier should have two arguments (width and height)")
        XCTAssertNotEqual(frameModifier.arguments.count, 1, "Frame should have both width and height arguments")
        
        // Verify width argument
        if let widthArg = frameModifier.arguments.first(where: { $0.label == .width }),
           case let .simple(widthData) = widthArg.value {
            XCTAssertEqual(widthData.value, "200", "Width should be 200")
            XCTAssertNotEqual(widthData.value, "100", "Width should not be 100")
            XCTAssertEqual(widthData.syntaxKind, .literal(.integer), "Width should be an integer")
        } else {
            XCTFail("Could not find or validate width argument")
        }
        
        // Verify height argument
        if let heightArg = frameModifier.arguments.first(where: { $0.label == .height }),
           case let .simple(heightData) = heightArg.value {
            XCTAssertEqual(heightData.value, "100", "Height should be 100")
            XCTAssertNotEqual(heightData.value, "200", "Height should not be 200")
            XCTAssertEqual(heightData.syntaxKind, .literal(.integer), "Height should be an integer")
        } else {
            XCTFail("Could not find or validate height argument")
        }
        
        // When - Convert to LayerData
        let layerData = try syntaxView.deriveStitchActions()
        
        // Then - Verify the structure of the LayerData
        // 1. Check that we have exactly one root layer (the Rectangle)
        XCTAssertEqual(layerData.layers.count, 1, "Should have exactly one layer")
        XCTAssertNotEqual(layerData.layers.count, 0, "Should have at least one layer")
        XCTAssertNotEqual(layerData.layers.count, 2, "Should not have multiple layers")
        
        let rectangleLayer = layerData.layers[0]
        
        // 2. Check that the layer is a rectangle
        if case let .layer(layerType) = rectangleLayer.node_name.value {
            XCTAssertEqual(layerType, .rectangle, "Layer type should be rectangle")
            XCTAssertNotEqual(layerType, .oval, "Layer should not be a oval")
        } else {
            XCTFail("Expected root layer to be a rectangle")
        }
        
        // 3. Verify size values in LayerData
        let sizeValues = layerData.custom_layer_input_values.filter { value in
            value.layer_input_coordinate.input_port_type.value == .size
        }
        
        // 4. Verify we have exactly one size value (combining width and height)
        XCTAssertEqual(sizeValues.count, 1, "Should have exactly one size value")
        XCTAssertNotEqual(sizeValues.count, 0, "Should have a size value")
        XCTAssertNotEqual(sizeValues.count, 2, "Should not have multiple size values")
        
        let sizeValue = sizeValues.first!
        
        // Verify the size is associated with the correct layer
        XCTAssertEqual(
            sizeValue.layer_input_coordinate.layer_id.value,
            rectangleLayer.node_id.value,
            "Size should be associated with the rectangle layer"
        )
        
        // 5. Verify the size value is 200x100
        if case let .size(size) = sizeValue.value {
            // Test exact size
            XCTAssertEqual(size.width, .number(200), "Width should be 200")
            XCTAssertEqual(size.height, .number(100), "Height should be 100")
            
            // Test incorrect sizes
            XCTAssertNotEqual(size.width, .number(100), "Width should be 200, not 100")
            XCTAssertNotEqual(size.height, .number(200), "Height should be 100, not 200")
            
            // Test with explicit values
            XCTAssertEqual(size, .init(width: 200, height: 100), "Size should be 200x100")
            XCTAssertNotEqual(size, .init(width: 100, height: 200), "Size should not be 100x200")
        } else {
            XCTFail("Expected size value to be a CGSize")
        }
        
        // 6. Verify no other unexpected input types exist for this layer
        let otherInputs = layerData.custom_layer_input_values.filter { input in
            input.layer_input_coordinate.layer_id.value == rectangleLayer.node_id.value &&
            input.layer_input_coordinate.input_port_type.value != .size
        }
        
        XCTAssertTrue(otherInputs.isEmpty, "Should not have any other input types for this layer")
    }
    
    func testTextWithStringLiteral() throws {
        // Given
        let code = #"Text("salut")"#
        
        // When - Parse the SwiftUI code into a SyntaxView
        guard let syntaxView = SwiftUIViewVisitor.parseSwiftUICode(code) else {
            XCTFail("Failed to parse Text example")
            return
        }
        
        // Then - Verify the SyntaxView structure
        // 1. Check the root view is a Text
        XCTAssertEqual(syntaxView.name, .text, "Root view should be a Text view")
        XCTAssertNotEqual(syntaxView.name, .vStack, "Should be a Text view, not a VStack")
        
        // 2. Verify the constructor argument (the string literal)
        XCTAssertEqual(syntaxView.constructorArguments.count, 1, "Text should have one constructor argument")
        XCTAssertNotEqual(syntaxView.constructorArguments.count, 0, "Text should have a string argument")
        XCTAssertNotEqual(syntaxView.constructorArguments.count, 2, "Text should have only one argument")
        
        let constructorArg = syntaxView.constructorArguments[0]
        XCTAssertEqual(constructorArg.label, .noLabel, "String argument should have no label")
        
        // 3. Verify the string literal value and its syntax kind
        XCTAssertEqual(constructorArg.values.count, 1, "Should have exactly one value")
        let value = constructorArg.values[0]
        
        XCTAssertEqual(value.value, "\"salut\"", "Text content should be 'salut'")
        XCTAssertNotEqual(value.value, "salut", "Text content should include quotes")
        XCTAssertEqual(value.syntaxKind, .literal(.string), "Text content should be a string literal")
        
        // 4. Verify no modifiers or children
        XCTAssertTrue(syntaxView.modifiers.isEmpty, "Text should have no modifiers")
        XCTAssertTrue(syntaxView.children.isEmpty, "Text should have no children")
        
        // When - Convert to LayerData
        let layerData = try syntaxView.deriveStitchActions()
        
        // Then - Verify the structure of the LayerData
        // 1. Check that we have exactly one layer (the Text)
        XCTAssertEqual(layerData.layers.count, 1, "Should have exactly one layer")
        XCTAssertNotEqual(layerData.layers.count, 0, "Should have at least one layer")
        XCTAssertNotEqual(layerData.layers.count, 2, "Should not have multiple layers")
        
        let textLayer = layerData.layers[0]
        
        // 2. Check that the layer is a text layer
        if case let .layer(layerType) = textLayer.node_name.value {
            XCTAssertEqual(layerType, .text, "Layer type should be text")
            XCTAssertNotEqual(layerType, .rectangle, "Layer should not be a rectangle")
        } else {
            XCTFail("Expected root layer to be a text layer")
        }
        
        // 3. Verify text value in LayerData
        let textValues = layerData.custom_layer_input_values.filter { value in
            value.layer_input_coordinate.input_port_type.value == .text
        }
        
        // 4. Verify we have exactly one text value
        XCTAssertEqual(textValues.count, 1, "Should have exactly one text value")
        XCTAssertNotEqual(textValues.count, 0, "Should have a text value")
        XCTAssertNotEqual(textValues.count, 2, "Should not have multiple text values")
        
        let textValue = textValues.first!
        
        // 5. Verify the text value is associated with the correct layer
        XCTAssertEqual(
            textValue.layer_input_coordinate.layer_id.value,
            textLayer.node_id.value,
            "Text value should be associated with the text layer"
        )
        
        // 6. Verify the text value is "salut" (with quotes)
        if case let .string(text) = textValue.value {
            XCTAssertEqual(text.string, "\"salut\"", "Text should be '\"salut\"'")
            XCTAssertNotEqual(text.string, "salut", "Text should include quotes")
        } else {
            XCTFail("Expected text value to be a string")
        }
        
        // 7. Verify no other unexpected input types exist for this layer
        let otherInputs = layerData.custom_layer_input_values.filter { input in
            input.layer_input_coordinate.layer_id.value == textLayer.node_id.value &&
            input.layer_input_coordinate.input_port_type.value != .text
        }
        
        XCTAssertTrue(otherInputs.isEmpty, "Should not have any other input types for this layer")
    }
}
