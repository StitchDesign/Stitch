//
//  CodeToSyntaxToActionsTests.swift
//  StitchTests
//
//  Created by Christian J Clampitt on 7/2/25.
//

import XCTest
@testable import Stitch
import SwiftUICore


final class ModifierTests: XCTestCase {
    
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
        
        let rectangleLayer = layerData
        
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
        let rectangleLayer = layerData
        
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
        let rectangleLayer = layerData
        
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
    
    
    func testRectangleWithRotationEffect() throws {
        // Given
        let code = """
        Rectangle()
            .rotationEffect(.degrees(45))
        """
        
        // When - Parse the SwiftUI code into a SyntaxView
        guard let syntaxView = SwiftUIViewVisitor.parseSwiftUICode(code) else {
            XCTFail("Failed to parse Rectangle with rotation effect example")
            return
        }
        
        // Then - Verify the SyntaxView structure
        // 1. Check the root view is a Rectangle
        XCTAssertEqual(syntaxView.name, .rectangle, "Root view should be a Rectangle")
        XCTAssertNotEqual(syntaxView.name, .text, "Should be a Rectangle, not a Text view")
        
        // 2. Verify no constructor arguments
        XCTAssertTrue(syntaxView.constructorArguments.isEmpty, "Rectangle should have no constructor arguments")
        
        // 3. Verify the rotation effect modifier
        XCTAssertEqual(syntaxView.modifiers.count, 1, "Should have one modifier")
        XCTAssertNotEqual(syntaxView.modifiers.count, 0, "Should have a rotation effect modifier")
        
        let modifier = syntaxView.modifiers[0]
        XCTAssertEqual(modifier.name, .rotationEffect, "Modifier should be rotationEffect")
        
        // 4. Verify the rotation effect arguments
        XCTAssertEqual(modifier.arguments.count, 1, "rotationEffect should have one argument")
        let angleArg = modifier.arguments[0]
        
        switch angleArg.value {
        case .angle(let angleData): // SyntaxViewModifierArgumentAngle
            XCTAssertEqual(angleData.value, "45", "Rotation angle should be 45 degrees")
        default:
            XCTFail("Should have had angle")
        }
        
        XCTAssertEqual(modifier.arguments.count, 1, "Should have had one argument")
         
        // 6. Verify no children
        XCTAssertTrue(syntaxView.children.isEmpty, "Rectangle should have no children")
        
        // When - Convert to LayerData
        let layerData = try syntaxView.deriveStitchActions()
        
        // Then - Verify the structure of the LayerData
        // 1. Check that we have exactly one layer (the Rectangle)
        let rectangleLayer = layerData
        
        // 2. Check that the layer is a rectangle
        if case let .layer(layerType) = rectangleLayer.node_name.value {
            XCTAssertEqual(layerType, .rectangle, "Layer type should be rectangle")
            XCTAssertNotEqual(layerType, .sfSymbol, "Layer should not be an SF Symbol")
        } else {
            XCTFail("Expected root layer to be a rectangle")
        }
        
        // 3. Verify rotation value in LayerData
        let rotationValues = layerData.custom_layer_input_values.filter { value in
            value.layer_input_coordinate.input_port_type.value == .rotationZ
        }
        
        // 4. Verify we have exactly one rotation value
        XCTAssertEqual(rotationValues.count, 1, "Should have exactly one rotation value")
        XCTAssertNotEqual(rotationValues.count, 0, "Should have a rotation value")
        
        let rotationValue = rotationValues.first!
        
        // 5. Verify the rotation value is associated with the correct layer
        XCTAssertEqual(
            rotationValue.layer_input_coordinate.layer_id.value,
            rectangleLayer.node_id.value,
            "Rotation value should be associated with the rectangle layer"
        )
        
        // 6. Verify the rotation value is 45 degrees
        switch rotationValue.value {
        case .number(let x):
            XCTAssertEqual(x, 45)
        default:
            XCTFail()
        }
        
       
        // 7. Verify no other unexpected input types exist for this layer
        let otherInputs = layerData.custom_layer_input_values.filter { input in
            input.layer_input_coordinate.layer_id.value == rectangleLayer.node_id.value &&
            input.layer_input_coordinate.input_port_type.value != .rotationZ
        }
        
        XCTAssertTrue(otherInputs.isEmpty, "Should not have any other input types for this layer")
    }
    
    func testRectangleWith3DRotationEffect() throws {
        // Given
        let code = """
        Rectangle()
            .rotation3DEffect(.degrees(60), axis: (x: 0, y: 1, z: 0))
        """
        
        // When - Parse the SwiftUI code into a SyntaxView
        guard let syntaxView = SwiftUIViewVisitor.parseSwiftUICode(code) else {
            XCTFail("Failed to parse Rectangle with 3D rotation effect example")
            return
        }
        
        // Then - Verify the SyntaxView structure
        // 1. Check the root view is a Rectangle
        XCTAssertEqual(syntaxView.name, .rectangle, "Root view should be a Rectangle")
        XCTAssertNotEqual(syntaxView.name, .text, "Should be a Rectangle, not a Text view")
        
        // 2. Verify no constructor arguments
        XCTAssertTrue(syntaxView.constructorArguments.isEmpty, "Rectangle should have no constructor arguments")
        
        // 3. Verify the rotation3DEffect modifier
        XCTAssertEqual(syntaxView.modifiers.count, 1, "Should have one modifier")
        let modifier = syntaxView.modifiers[0]
        XCTAssertEqual(modifier.name, .rotation3DEffect, "Modifier should be rotation3DEffect")
        
        // 4. Verify the rotation3DEffect arguments
        XCTAssertEqual(modifier.arguments.count, 2, "rotation3DEffect should have two arguments")
        
        // 5. Verify the angle argument
        let angleArg = modifier.arguments[0]
        switch angleArg.value {
        case .angle(let angleData):
            XCTAssertEqual(angleData.value, "60", "Rotation angle should be 60 degrees")
        default:
            XCTFail("First argument should be an angle")
        }
        
        // 6. Verify the axis argument
        let axisArg = modifier.arguments[1]
        XCTAssertEqual(axisArg.label.rawValue, "axis", "Second argument should be labeled 'axis'")
        
        // 7. Verify no children
        XCTAssertTrue(syntaxView.children.isEmpty, "Rectangle should have no children")
        
        // When - Convert to LayerData
        let layerData = try syntaxView.deriveStitchActions()
        
        // Then - Verify the structure of the LayerData
        // 1. Check that we have exactly one layer (the Rectangle)
        let rectangleLayer = layerData
        
        // 2. Check that the layer is a rectangle
        if case let .layer(layerType) = rectangleLayer.node_name.value {
            XCTAssertEqual(layerType, .rectangle, "Layer type should be rectangle")
        } else {
            XCTFail("Expected root layer to be a rectangle")
        }
        
        // 3. Verify rotation value in LayerData (should be around Y axis)
        let rotationYValues = layerData.custom_layer_input_values.filter { value in
            value.layer_input_coordinate.input_port_type.value == .rotationY
        }
        
        // 4. Verify we have exactly one rotation value (around Y axis)
        XCTAssertEqual(rotationYValues.count, 1, "Should have exactly one Y rotation value")
        
        let rotationValue = rotationYValues.first!
        
        // 5. Verify the rotation value is associated with the correct layer
        XCTAssertEqual(
            rotationValue.layer_input_coordinate.layer_id.value,
            rectangleLayer.node_id.value,
            "Rotation value should be associated with the rectangle layer"
        )
        
        // 6. Verify the rotation value is 60 degrees
        switch rotationValue.value {
        case .number(let degrees):
            XCTAssertEqual(degrees, 60, "Rotation should be 60 degrees around Y axis")
        default:
            XCTFail("Expected rotation value to be a number")
        }
        
        // 7. Verify no other rotation values exist for this layer
        let otherRotations = layerData.custom_layer_input_values.filter { input in
            let portType = input.layer_input_coordinate.input_port_type.value
            return input.layer_input_coordinate.layer_id.value == rectangleLayer.node_id.value &&
                  (portType == .rotationX || portType == .rotationZ)
        }
        
        XCTAssertTrue(otherRotations.isEmpty, "Should not have any other rotation values for this layer")
    }
}
