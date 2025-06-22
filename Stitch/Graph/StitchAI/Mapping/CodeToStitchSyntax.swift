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
    print("\n==== PARSING CODE ====\n\(swiftUICode)\n=====================\n")
    
    // Fall back to the original visitor-based approach for now
    // but add our own post-processing for modifiers
    let sourceFile = Parser.parse(source: swiftUICode)
    
    print("\n==== DEBUG: SOURCE FILE STRUCTURE ====\n")
    dump(sourceFile)
    print("\n==== END DEBUG DUMP ====\n")
    
    // Create a visitor that will extract the view structure
    let visitor = SwiftUIViewVisitor(viewMode: .sourceAccurate)
    visitor.walk(sourceFile)
    return visitor.rootViewNode
    
//    // Post-process to extract modifiers from the code directly
//    if var viewNode = visitor.rootViewNode {
//        // Use string-based detection as a simple but effective approach
//        let modifiers = extractModifiers(from: swiftUICode)
//        if !modifiers.isEmpty {
//            viewNode.modifiers = modifiers
//            print("Added \(modifiers.count) modifiers via direct extraction")
//        }
//        return viewNode
//    }
//
//    return nil
}

/// Extract modifiers from SwiftUI code using a simple but effective string-based approach
func extractModifiers(from swiftUICode: String) -> [Modifier] {
    var modifiers: [Modifier] = []
    
    // Remove whitespace for easier parsing
    let code = swiftUICode.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    print("Normalized code for modifier extraction: \(code)")
    
    // Identify the main view name so we can find modifiers that belong to it
    guard let mainViewMatch = code.range(of: "(Text|Button|VStack|HStack|ZStack|Image|List|ScrollView|ForEach)\\s*\\(", options: .regularExpression) else {
        print("Could not identify main view in code")
        return modifiers
    }
    
    // Extract just the portion of code with modifiers (after the main view)
    let mainViewPosition = code.distance(from: code.startIndex, to: mainViewMatch.lowerBound)
    let modifierCode = String(code.dropFirst(mainViewPosition))
    print("Modifier portion of code: \(modifierCode)")
    
    // Basic pattern: look for .modifierName(...) patterns
    let pattern = "\\.([a-zA-Z][a-zA-Z0-9_]*)\\s*\\(([^\\)]*)\\)"
    
    do {
        let regex = try NSRegularExpression(pattern: pattern, options: [])
        let matches = regex.matches(in: modifierCode, options: [], range: NSRange(location: 0, length: modifierCode.count))
        
        print("Found \(matches.count) potential modifiers in code")
        
        for match in matches {
            if match.numberOfRanges >= 3,
               let modifierNameRange = Range(match.range(at: 1), in: modifierCode),
               let argumentsRange = Range(match.range(at: 2), in: modifierCode) {
                
                let modifierName = String(modifierCode[modifierNameRange])
                let argumentsText = String(modifierCode[argumentsRange])
                
                print("Extracted modifier: .\(modifierName)(\(argumentsText))")
                
                // Parse arguments (simplified)
                var arguments: [(label: String?, value: String)] = []
                let args = argumentsText.components(separatedBy: ",")
                
                for arg in args {
                    let trimmedArg = arg.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmedArg.isEmpty { continue }
                    
                    // Check if it has a label (name: value)
                    if let colonIndex = trimmedArg.firstIndex(of: ":") {
                        let label = String(trimmedArg[..<colonIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                        let value = String(trimmedArg[trimmedArg.index(after: colonIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                        arguments.append((label: label, value: value))
                    } else {
                        // No label
                        arguments.append((label: nil, value: trimmedArg))
                    }
                }
                
                // Create the modifier
                let modifier = Modifier(
                    name: modifierName,
                    value: arguments.count == 1 && arguments[0].label == nil ? arguments[0].value : "",
                    arguments: arguments
                )
                
                modifiers.append(modifier)
            }
        }
    } catch {
        print("Error creating regex: \(error)")
    }
    
    return modifiers
}

/// SwiftSyntax visitor that extracts ViewNode structure from SwiftUI code
class SwiftUIViewVisitor: SyntaxVisitor {
    var rootViewNode: ViewNode?
    private var currentNodeIndex: Int? // Index into the view stack
    private var viewStack: [ViewNode] = []
    private var idCounter = 0
    
    // Debug logging for tracing the parsing process
    private func log(_ message: String) {
        print("[SwiftUIParser] \(message)")
    }
    
    private func dbg(_ message: String) {
    #if DEV_DEBUG
        print("🔍 [ModifierDebug] \(message)")
    #endif
    }
    
    // Generates a unique ID for a view node
    private func generateUniqueID(for viewName: String) -> String {
        idCounter += 1
        return viewName.lowercased() + String(idCounter)
    }
    
    // Helper to get current ViewNode
    private var currentViewNode: ViewNode? {
        guard let index = currentNodeIndex, index < viewStack.count else { return nil }
        return viewStack[index]
    }
    
    // Helper to update currentViewNode properly
    private func updateCurrentViewNode(_ newNode: ViewNode) {
        guard let index = currentNodeIndex, index < viewStack.count else { return }
        viewStack[index] = newNode
        
        // If this is the root node, update rootViewNode too
        if index == 0 {
            rootViewNode = newNode
        } else if index > 0 {
            // Update this node as a child in its parent
            let parentIndex = index - 1
            var parent = viewStack[parentIndex]
            if !parent.children.isEmpty {
                // Find and replace the appropriate child
                for (childIndex, child) in parent.children.enumerated() {
                    if child.id == newNode.id {
                        parent.children[childIndex] = newNode
                        viewStack[parentIndex] = parent
                        break
                    }
                }
            }
        }
    }
    
    // Helper to add a modifier to the current view node
    private func addModifier(_ modifier: Modifier) {
        dbg("addModifier → \(modifier.name) to current index \(String(describing: currentNodeIndex))")
        guard let index = currentNodeIndex, index < viewStack.count else {
            log("⚠️ Cannot add modifier: no current view node")
            return
        }
        
        var node = viewStack[index]
        log("Adding modifier \(modifier.name) to \(node.name)")
        node.modifiers.append(modifier)
        viewStack[index] = node
        
        // If this is the root node, update rootViewNode too
        if index == 0 {
            rootViewNode = node
        } else {
            // Update this node as a child in its parent
            let parentIndex = index - 1
            var parent = viewStack[parentIndex]
            if !parent.children.isEmpty {
                // Find and replace the appropriate child
                for (childIndex, child) in parent.children.enumerated() {
                    if child.id == node.id {
                        parent.children[childIndex] = node
                        viewStack[parentIndex] = parent
                        // Keep rootViewNode in sync when we modify a direct child of the root
                        if parentIndex == 0 {
                            rootViewNode = parent
                        }
                        break
                    }
                }
            }
        }
        log("✅ After adding modifier - modifiers count: \(node.modifiers.count)")
        dbg("addModifier → completed. Node \(node.name) now has \(node.modifiers.count) modifier(s).")
    }
    
    // Visit function call expressions (which represent view initializations and modifiers)
    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        log("Visiting function call: \(node.description)")
        log("Current stack depth: \(viewStack.count), current index: \(String(describing: currentNodeIndex))")
        
        if let identifierExpr = node.calledExpression.as(IdentifierExprSyntax.self) {
            // This might be a view initialization like Text("Hello")
            let viewName = identifierExpr.identifier.text
            log("Found view initialization: \(viewName)")
            
            // Create a new ViewNode for this view
            let viewNode = ViewNode(
                name: viewName,
                arguments: parseArguments(from: node),
                modifiers: [],
                children: [],
                id: generateUniqueID(for: viewName)
            )
            log("Created new ViewNode for \(viewName) with \(viewNode.arguments.count) arguments")
            
            // Set as root or add as child to current node
            if viewStack.isEmpty {
                log("Setting as root ViewNode: \(viewName)")
                viewStack.append(viewNode)
                currentNodeIndex = 0
                rootViewNode = viewNode
                log("Current node index set to: \(String(describing: currentNodeIndex))")
            } else {
                // Add as child to the current view node
                if let currentNode = currentViewNode {
                    log("Adding \(viewName) as child to \(currentNode.name)")
                    var updatedCurrentNode = currentNode
                    updatedCurrentNode.children.append(viewNode)
                    updateCurrentViewNode(updatedCurrentNode)
                    
                    // Push the new node onto the stack and update current node index
                    viewStack.append(viewNode)
                    currentNodeIndex = viewStack.count - 1
                    log("Pushed \(viewName) onto stack, new index: \(String(describing: currentNodeIndex))")
                } else {
                    log("⚠️ Error: No current node to add child to")
                }
            }
            
        } else if let memberAccessExpr = node.calledExpression.as(MemberAccessExprSyntax.self) {
            // Detected a modifier call (e.g. .padding()).  We *do not* attach the modifier
            // here because the base view may not have been pushed onto the stack yet.
            // Instead, we defer actual attachment to `visitPost(_:)`, which runs after the
            // base `FunctionCallExprSyntax` has been visited.
            dbg("visit → encountered potential modifier .\(memberAccessExpr.name.text) – deferring to visitPost")
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
    
        dbg("parseArguments → for \(node.calledExpression.trimmedDescription)  |  \(arguments.count) arg(s): \(arguments)")
        
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
        log("Visiting post for function call: \(node.description)")
        
        if let identExpr = node.calledExpression.as(IdentifierExprSyntax.self) {
            let viewName = identExpr.identifier.text
            log("Post-visiting view initialization: \(viewName)")
            // If this view call is the *base* of a MemberAccessExpr (e.g. Rectangle() in
            // Rectangle().frame(...)), we **keep** it on the stack so that the upcoming
            // modifier call can still access and mutate the current view node.
            if node.parent?.as(MemberAccessExprSyntax.self) != nil {
                log("Deferring pop for \(viewName) because it is base of a modifier chain")
                return
            }
            log("ViewStack before adjustment - count: \(viewStack.count), current node index: \(String(describing: currentNodeIndex))")
            
            // Debug the current stack state
            if !viewStack.isEmpty {
                log("Current stack state:")
                for (index, stackNode) in viewStack.enumerated() {
                    log("  [\(index)] \(stackNode.name) with \(stackNode.modifiers.count) modifiers")
                }
            }
            
            // We're exiting a view initialization
            if !viewStack.isEmpty {
                // Before removing the node, make sure we capture any modifiers that were added
                let lastNode = viewStack.last
                log("Node being popped: \(lastNode?.name ?? "unknown") with \(lastNode?.modifiers.count ?? 0) modifiers")
                
                // Remove the last node
                viewStack.removeLast()
                
                // Update current node index to point to the new last node
                currentNodeIndex = viewStack.count > 0 ? viewStack.count - 1 : nil
                
                log("Stack after pop - depth: \(viewStack.count), new current index: \(String(describing: currentNodeIndex))")
                
                // Debug the root node state
                if let root = rootViewNode {
                    log("Root node: \(root.name) with \(root.modifiers.count) modifiers and \(root.children.count) children")
                    if !root.children.isEmpty {
                        for (index, child) in root.children.enumerated() {
                            log("  Root child[\(index)]: \(child.name) with \(child.modifiers.count) modifiers")
                        }
                    }
                }
            } else {
                log("View stack empty, nothing to pop")
            }
        }
        // ─────────────────────────────────────────────────────────────
        // Handle modifiers *after* the base view has been visited
        // (at this point `currentViewNode` should refer to the view
        //  we want to attach the modifier to).
        else if let memberAccessExpr = node.calledExpression.as(MemberAccessExprSyntax.self) {
            let modifierName = memberAccessExpr.name.text
            dbg("visitPost → attaching modifier '\(modifierName)'")

            // Parse the arguments for this modifier
            let modifierArguments = parseArguments(from: node)
            dbg("visitPost → '\(modifierName)' argCount: \(modifierArguments.count)")

            let modifier = Modifier(
                name: modifierName,
                value: modifierArguments.count == 1 && modifierArguments[0].label == nil
                       ? modifierArguments[0].value
                       : "",
                arguments: modifierArguments
            )

            // Finally, attach the modifier to the current view node
            addModifier(modifier)

            // If this FunctionCallExpr is **not** itself nested inside another
            // MemberAccessExpr, we have reached the end of the modifier chain
            // for the current base view. At this point we can safely pop the
            // base view from the stack so that subsequent sibling views attach
            // to the correct parent (e.g. the ZStack in `ZStack { Rectangle()… }`).
            if node.parent?.as(MemberAccessExprSyntax.self) == nil {
                if let popped = viewStack.popLast() {
                    dbg("visitPost → popped view \(popped.name) after completing modifier chain")
                }
                currentNodeIndex = viewStack.isEmpty ? nil : viewStack.count - 1
            }
        }
    }
}

// Example usage function to test the parsing
func testSwiftUIToViewNode(swiftUICode: String) {
    if let viewNode = parseSwiftUICode(swiftUICode) {
        print("\n==== PARSED VIEWNODE RESULT ====\n")
        print("Name: \(viewNode.name)")
        print("Arguments: \(viewNode.arguments)")
        print("Modifiers (\(viewNode.modifiers.count)):")
        for (index, modifier) in viewNode.modifiers.enumerated() {
            print("  [\(index)] \(modifier.name)(\(modifier.value))")
            if !modifier.arguments.isEmpty {
                print("    Arguments:")
                for arg in modifier.arguments {
                    print("      \(arg.label ?? "_"): \(arg.value)")
                }
            }
        }
        print("Children: \(viewNode.children.count)")
        print("============================\n")
    } else {
        print("Failed to parse SwiftUI code")
    }
}

// Run a simple test with a Text view that has modifiers
func runModifierParsingTest() {
    print("\n==== TESTING MODIFIER PARSING ====\n")
    
    let testCode = "Text(\"Hello\").foregroundColor(.blue).padding()"
    print("Test code: \(testCode)")
    
    testSwiftUIToViewNode(swiftUICode: testCode)
    
    print("\n==== TEST COMPLETE ====\n")
}


