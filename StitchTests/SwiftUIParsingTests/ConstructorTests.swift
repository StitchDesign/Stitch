//
//  ConstructorTests.swift
//  StitchTests
//
//  Created by Christian J Clampitt on 7/2/25.
//

import XCTest
@testable import Stitch
import SwiftUICore


final class ConstructorTests: XCTestCase {

    func testRoundedRectangleWithCornerRadius() throws {
        // Given
        let code = """
        RoundedRectangle(cornerRadius: 25)
        """
        
        // When - Parse the SwiftUI code into a SyntaxView
        guard let syntaxView = SwiftUIViewVisitor.parseSwiftUICode(code).rootView else {
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
        guard let layerData = try syntaxView.deriveStitchActions().actions.first else {
            XCTFail()
            return
        }
        
        // Then - Verify the structure of the LayerData
        // 1. Check that we have exactly one root layer (the RoundedRectangle)
        let roundedRectLayer = layerData
        
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

    func testTextWithStringLiteral() throws {
        // Given
        let code = #"Text("salut")"#
        
        // When - Parse the SwiftUI code into a SyntaxView
        guard let syntaxView = SwiftUIViewVisitor.parseSwiftUICode(code).rootView else {
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
        guard let layerData = try syntaxView.deriveStitchActions().actions.first else {
            XCTFail()
            return
        }
        
        // Then - Verify the structure of the LayerData
        // 1. Check that we have exactly one layer (the Text)
        let textLayer = layerData
        
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
    
    func testImageWithSFSymbol() throws {
        // Given
        let code = #"Image(systemName: "star.fill")"#
        
        // When - Parse the SwiftUI code into a SyntaxView
        guard let syntaxView = SwiftUIViewVisitor.parseSwiftUICode(code).rootView else {
            XCTFail("Failed to parse Image with SF Symbol example")
            return
        }
        
        // Then - Verify the SyntaxView structure
        // 1. Check the root view is an Image
        XCTAssertEqual(syntaxView.name, .image, "Root view should be an Image view")
        XCTAssertNotEqual(syntaxView.name, .text, "Should be an Image view, not a Text view")
        
        // 2. Verify the constructor argument with systemName label
        XCTAssertEqual(syntaxView.constructorArguments.count, 1, "Image should have one constructor argument")
        XCTAssertNotEqual(syntaxView.constructorArguments.count, 0, "Image should have a systemName argument")
        
        let constructorArg = syntaxView.constructorArguments[0]
        XCTAssertEqual(constructorArg.label, .systemName, "Argument should be labeled 'systemName'")
        
        // 3. Verify the string literal value and its syntax kind
        XCTAssertEqual(constructorArg.values.count, 1, "Should have exactly one value")
        let value = constructorArg.values[0]
        
        XCTAssertEqual(value.value, "\"star.fill\"", "SF Symbol name should be 'star.fill'")
        XCTAssertNotEqual(value.value, "star.fill", "SF Symbol name should include quotes")
        XCTAssertEqual(value.syntaxKind, .literal(.string), "SF Symbol name should be a string literal")
        
        // 4. Verify no modifiers or children
        XCTAssertTrue(syntaxView.modifiers.isEmpty, "Image should have no modifiers")
        XCTAssertTrue(syntaxView.children.isEmpty, "Image should have no children")
        
        // When - Convert to LayerData
        guard let layerData = try syntaxView.deriveStitchActions().actions.first else {
            XCTFail()
            return
        }
        
        // Then - Verify the structure of the LayerData
        // 1. Check that we have exactly one layer (the SF Symbol)
        let symbolLayer = layerData
        
        // 2. Check that the layer is an SF Symbol layer
        if case let .layer(layerType) = symbolLayer.node_name.value {
            XCTAssertEqual(layerType, .sfSymbol, "Layer type should be sfSymbol")
            XCTAssertNotEqual(layerType, .text, "Layer should not be a text layer")
        } else {
            XCTFail("Expected root layer to be an SF Symbol layer")
        }
        
        // 3. Verify SF Symbol value in LayerData
        let symbolValues = layerData.custom_layer_input_values.filter { value in
            value.layer_input_coordinate.input_port_type.value == .sfSymbol
        }
        
        // 4. Verify we have exactly one SF Symbol value
        XCTAssertEqual(symbolValues.count, 1, "Should have exactly one SF Symbol value")
        XCTAssertNotEqual(symbolValues.count, 0, "Should have an SF Symbol value")
        
        let symbolValue = symbolValues.first!
        
        // 5. Verify the SF Symbol value is associated with the correct layer
        XCTAssertEqual(
            symbolValue.layer_input_coordinate.layer_id.value,
            symbolLayer.node_id.value,
            "SF Symbol value should be associated with the SF Symbol layer"
        )
        
        // 6. Verify the SF Symbol value is "star.fill" (with quotes)
        if case let .string(symbolName) = symbolValue.value {
            XCTAssertEqual(symbolName.string, "\"star.fill\"", "SF Symbol should be '\"star.fill\"'")
            XCTAssertNotEqual(symbolName.string, "star.fill", "SF Symbol should include quotes")
        } else {
            XCTFail("Expected SF Symbol value to be a string")
        }
        
        // 7. Verify no other unexpected input types exist for this layer
        let otherInputs = layerData.custom_layer_input_values.filter { input in
            input.layer_input_coordinate.layer_id.value == symbolLayer.node_id.value &&
            input.layer_input_coordinate.input_port_type.value != .sfSymbol
        }
        
        XCTAssertTrue(otherInputs.isEmpty, "Should not have any other input types for this layer")
    }

}
