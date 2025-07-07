//
//  StitchSyntaxToCode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/21/25.
//

import Foundation
import SwiftUI
import SwiftSyntax
import SwiftParser

// MARK: - ViewNode to SwiftUI Code

/// Converts a ViewNode to SwiftUI code string
func swiftUICode(from node: SyntaxView, indentation: String = "") -> String {
    var code = ""
    
    // Start with the view name
    code += node.name.rawValue
    
    // Add arguments in parentheses if there are any
    if !node.constructorArguments.isEmpty {
        code += "("
        
        // Add each argument
        let args = node.constructorArguments.enumerated().map { index, arg -> String in
            // If there's a label, include it followed by a colon
            let label = arg.label == nil ? "" : "\(arg.label!): "
            let values = arg.value //.map { $0.value }.joined(separator: ", ")
            return "\(label)\(values)"
        }.joined(separator: ", ")
        
        code += args
        code += ")"
    } else {
        // Empty parentheses for initializers without arguments
        if node.children.isEmpty {
            code += "()"
        }
    }
    
    // Add modifiers
    for modifier in node.modifiers {
        code += "\n\(indentation)    ."
        code += modifier.name.rawValue
        
        // Handle the modifier value or arguments
        if !modifier.arguments.isEmpty {
            // Complex modifier with labeled arguments
            code += "("
            
            let args = modifier.arguments.enumerated().map { index, arg -> String in
                let label = arg.label == nil ? "" : "\(arg.label!): "
                return "\(label)\(arg.value)"
            }.joined(separator: ", ")
            
            code += args
            code += ")"
        }
            else {
            // Modifier with no arguments (like .padding() with no arguments)
            code += "()"
        }
    }
    
    // Add children in a closure if there are any
    if !node.children.isEmpty {
        if node.constructorArguments.isEmpty {
            code += " {"
        } else {
            code += "{" // Add space before brace for views with arguments
        }
        
        // Add each child with increased indentation
        for child in node.children {
            code += "\n\(indentation)    \(swiftUICode(from: child, indentation: indentation + "    "))"
        }
        
        code += "\n\(indentation)}"
    }
    
    return code
}

// Example usage function to test the conversion
func testViewNodeToSwiftUI(viewNode: SyntaxView) {
    let code = swiftUICode(from: viewNode)
    print("Generated SwiftUI code:\n\n\(code)\n")
}

