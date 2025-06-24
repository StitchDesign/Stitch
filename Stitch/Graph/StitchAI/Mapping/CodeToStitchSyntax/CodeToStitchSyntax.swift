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
import SwiftSyntaxBuilder


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
    
    /// Propagate a mutation at `index` upward through `viewStack`
    /// so that every ancestor’s `children` array is updated
    /// and `rootViewNode` stays in sync.
    private func bubbleChangeUp(from index: Int) {
        var childIndex = index
        while childIndex > 0 {
            let parentIndex = childIndex - 1
            var parent = viewStack[parentIndex]
            let child   = viewStack[childIndex]
            
            if let match = parent.children.firstIndex(where: { $0.id == child.id }) {
                parent.children[match] = child
                viewStack[parentIndex] = parent
            } else {
                // Shouldn’t happen, but avoid infinite loop
                break
            }
            childIndex = parentIndex
        }
        if !viewStack.isEmpty {
            rootViewNode = viewStack[0]
        }
    }

    // Helper to update currentViewNode properly
    private func updateCurrentViewNode(_ newNode: ViewNode) {
        guard let index = currentNodeIndex, index < viewStack.count else { return }
        viewStack[index] = newNode
        bubbleChangeUp(from: index)
    }
    
    // Helper to add a modifier to the current view node
    private func addModifier(_ modifier: Modifier) {
        let modName = modifier.kind.rawValue
        dbg("addModifier → \(modName) to current index \(String(describing: currentNodeIndex))")
        guard let index = currentNodeIndex, index < viewStack.count else {
            log("⚠️ Cannot add modifier: no current view node")
            return
        }
        
        var node = viewStack[index]
        log("Adding modifier \(modName) to \(node.name.string)")
        node.modifiers.append(modifier)
        viewStack[index] = node
        // Bubble the change up to keep all ancestors current
        bubbleChangeUp(from: index)
        log("✅ After adding modifier - modifiers count: \(node.modifiers.count)")
        dbg("addModifier → completed. Node \(node.name.string) now has \(node.modifiers.count) modifier(s).")
    }
    
    // Visit function call expressions (which represent view initializations and modifiers)
    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        log("Visiting function call: \(node.description)")
        log("Current stack depth: \(viewStack.count), current index: \(String(describing: currentNodeIndex))")
        
        if let identifierExpr = node.calledExpression.as(DeclReferenceExprSyntax.self) {
            // This might be a view initialization like Text("Hello")
            let viewName = identifierExpr.baseName.text
            log("Found view initialization: \(viewName)")
            
            // Create a new ViewNode for this view
            let viewNode = ViewNode(
                name: .init(from: viewName),
                // This is creat
                arguments: parseArgumentsForConstructor(from: node),
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
                    log("Adding \(viewName) as child to \(currentNode.name.string)")
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
            dbg("visit → encountered potential modifier .\(memberAccessExpr.declName.baseName.text) – deferring to visitPost")
        }
        
        return .visitChildren
    }

    // Parse arguments from function call
    private func parseArgumentsForConstructor(from node: FunctionCallExprSyntax) -> [ConstructorArgument] {
        let arguments = node.arguments.map { argument in
            let label: String? = argument.label?.text
            let expression = argument.expression
            return ConstructorArgument(
                label: label.map { ConstructorArgumentLabel.from($0) } ?? nil,
                value: expression.trimmedDescription,
                syntaxKind: .fromExpression(expression)
            )
        }
        
        dbg("parseArguments → for \(node.calledExpression.trimmedDescription)  |  \(arguments.count) arg(s): \(arguments)")
        
        return arguments
    }
    
    // Parse arguments from function call
    private func parseArgumentsForModifier(from node: FunctionCallExprSyntax) -> [Argument] {
        let arguments = node.arguments.map { argument in
            let label = argument.label?.text
            let expression = argument.expression
            return Argument(
                label: label,
                value: expression.trimmedDescription,
                syntaxKind: .fromExpression(expression)
            )
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
        
        if let identExpr = node.calledExpression.as(DeclReferenceExprSyntax.self) {
            let viewName = identExpr.baseName.text
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
                    log("  [\(index)] \(stackNode.name.string) with \(stackNode.modifiers.count) modifiers")
                }
            }
            
            // We're exiting a view initialization
            if !viewStack.isEmpty {
                // Before removing the node, make sure we capture any modifiers that were added
                let lastNode = viewStack.last
                log("Node being popped: \(lastNode?.name.string ?? "unknown") with \(lastNode?.modifiers.count ?? 0) modifiers")
                
                // Remove the last node
                viewStack.removeLast()
                
                // Update current node index to point to the new last node
                currentNodeIndex = viewStack.count > 0 ? viewStack.count - 1 : nil
                
                log("Stack after pop - depth: \(viewStack.count), new current index: \(String(describing: currentNodeIndex))")
                
                // Debug the root node state
                if let root = rootViewNode {
                    log("Root node: \(root.name.string) with \(root.modifiers.count) modifiers and \(root.children.count) children")
                    if !root.children.isEmpty {
                        for (index, child) in root.children.enumerated() {
                            log("  Root child[\(index)]: \(child.name.string) with \(child.modifiers.count) modifiers")
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
            let modifierName = memberAccessExpr.declName.baseName.text
            dbg("visitPost → attaching modifier '\(modifierName)'")

            // Parse the arguments for this modifier
            let modifierArguments = parseArgumentsForModifier(from: node)
            
            dbg("visitPost → '\(modifierName)' argCount: \(modifierArguments.count)")

            var finalArgs = modifierArguments
            if finalArgs.isEmpty {
                // `.padding()` → synthetic unknown literal
                finalArgs = [Argument(label: nil, value: "", syntaxKind: .literal(.unknown))]
            }
            let modifier = Modifier(
                kind: ModifierKind(rawValue: modifierName),
                arguments: finalArgs
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
                    dbg("visitPost → popped view \(popped.name.string) after completing modifier chain")
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
        print("Name: \(viewNode.name.string)")
        print("Arguments: \(viewNode.arguments)")
        print("Modifiers (\(viewNode.modifiers.count)):")
        for (index, modifier) in viewNode.modifiers.enumerated() {
            print("  [\(index)] \(modifier.kind.rawValue))")
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
