//
//  CodeToStitchSyntax.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/21/25.
//

import Foundation
import SwiftUI
import SwiftSyntax
import SwiftParser

// MARK: - SwiftUI Code to ViewNode

/// Parses SwiftUI code into a ViewNode structure
func parseSwiftUICode(_ swiftUICode: String) -> ViewNode? {
    // First step is to parse the provided SwiftUI code into a syntax tree
    let sourceFile = Parser.parse(source: swiftUICode)
    
    // Create a visitor that will extract the view structure
    let visitor = SwiftUIViewVisitor(viewMode: .sourceAccurate)
    visitor.walk(sourceFile)
    
    return visitor.rootViewNode
}

/// SwiftSyntax visitor that extracts ViewNode structure from SwiftUI code
class SwiftUIViewVisitor: SyntaxVisitor {
    var rootViewNode: ViewNode?
    private var currentViewNode: ViewNode?
    private var viewStack: [ViewNode] = []
    private var idCounter = 0
    
    // Generates a unique ID for a view node
    private func generateUniqueID(for viewName: String) -> String {
        idCounter += 1
        return viewName.lowercased() + String(idCounter)
    }
    
    // Visit function call expressions (which represent view initializations and modifiers)
    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        if let identifierExpr = node.calledExpression.as(IdentifierExprSyntax.self) {
            // This might be a view initialization like Text("Hello")
            let viewName = identifierExpr.identifier.text
            
            // Create a new ViewNode for this view
            let viewNode = ViewNode(
                name: viewName,
                arguments: parseArguments(from: node),
                modifiers: [],
                children: [],
                id: generateUniqueID(for: viewName)
            )
            
            // Set as current or add to parent
            if currentViewNode == nil {
                currentViewNode = viewNode
                rootViewNode = viewNode
            } else {
                // Add as child to the current view node
                currentViewNode?.children.append(viewNode)
            }
            
            // Push this view onto the stack for handling its children
            viewStack.append(viewNode)
            currentViewNode = viewNode
            
        } else if let memberAccessExpr = node.calledExpression.as(MemberAccessExprSyntax.self) {
            // This might be a modifier like .padding() or .foregroundColor(Color.blue)
            if let baseExpr = memberAccessExpr.base,
               currentViewNode.isDefined {
                
                // This is a modifier applied to a view
                let modifierName = memberAccessExpr.name.text
                
                // Parse modifier arguments
                let modifierArguments = parseArguments(from: node)
                
                // Create a new Modifier and add it to the current view
                let modifier = Modifier(
                    name: modifierName,
                    value: modifierArguments.count == 1 && modifierArguments[0].label == nil ? modifierArguments[0].value : "",
                    arguments: modifierArguments
                )
                
                currentViewNode?.modifiers.append(modifier)
            }
        }
        
        return .visitChildren
    }
    
    // Parse arguments from function call
    private func parseArguments(from node: FunctionCallExprSyntax) -> [(label: String?, value: String)] {
        var arguments: [(label: String?, value: String)] = []
        
        for argument in node.argumentList {
            let label = argument.label?.text
            
            // Convert the expression to a string
            let valueText = argument.expression.description.trimmingCharacters(in: .whitespacesAndNewlines)
            
            arguments.append((label: label, value: valueText))
        }
        
        return arguments
    }
    
    // Handle closure expressions (for container views like VStack, HStack, ZStack)
    override func visit(_ node: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
        // Remember parent view before entering the closure
        // The statements inside will be children of the current view
        return .visitChildren
    }
    
    // When we finish visiting a node, manage the view stack
    override func visitPost(_ node: FunctionCallExprSyntax) {
        if let _ = node.calledExpression.as(IdentifierExprSyntax.self) {
            // We're exiting a view initialization
            if !viewStack.isEmpty {
                viewStack.removeLast()
                currentViewNode = viewStack.last
            }
        }
    }
}

// Example usage function to test the parsing
func testSwiftUIToViewNode(swiftUICode: String) {
    if let viewNode = parseSwiftUICode(swiftUICode) {
        print("Parsed ViewNode:\n\n\(viewNode)\n")
    } else {
        print("Failed to parse SwiftUI code")
    }
}


