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

extension SwiftUIViewVisitor {
    /// Parses SwiftUI code into a ViewNode structure
    static func parseSwiftUICode(_ swiftUICode: String) -> SyntaxView? {
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
}

/// SwiftSyntax visitor that extracts ViewNode structure from SwiftUI code
final class SwiftUIViewVisitor: SyntaxVisitor {
    var rootViewNode: SyntaxView?
    private var currentNodeIndex: Int? // Index into the view stack
    private var viewStack: [SyntaxView] = []
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
    
    // Helper to get current ViewNode
    private var currentViewNode: SyntaxView? {
        guard let index = currentNodeIndex, index < viewStack.count else { return nil }
        return viewStack[index]
    }
    
    /// Returns the modifier name if `node` is a *view modifier* call
    /// (i.e. a `FunctionCallExprSyntax` whose `calledExpression` is a
    /// `MemberAccessExprSyntax` **with a non‑nil base**).
    /// Helper/static calls that appear only as *arguments* – such as
    /// `.degrees(90)` or `.black` – have `base == nil`, so they are
    /// filtered out.
    private func modifierNameIfViewModifier(_ node: FunctionCallExprSyntax) -> String? {
        guard let member = node.calledExpression.as(MemberAccessExprSyntax.self),
              member.base != nil      // nil ⇒ helper call, not a modifier
        else { return nil }
        return member.declName.baseName.text
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
    private func updateCurrentViewNode(_ newNode: SyntaxView) {
        guard let index = currentNodeIndex, index < viewStack.count else { return }
        viewStack[index] = newNode
        bubbleChangeUp(from: index)
    }
    
    // Helper to add a modifier to the current view node
    private func addModifier(_ modifier: SyntaxViewModifier) {
        let modName = modifier.name.rawValue
        dbg("addModifier → \(modName) to current index \(String(describing: currentNodeIndex))")
        guard let index = currentNodeIndex, index < viewStack.count else {
            log("⚠️ Cannot add modifier: no current view node")
            return
        }
        
        var node = viewStack[index]
        log("Adding modifier \(modName) to \(node.name.rawValue)")
        node.modifiers.append(modifier)
        viewStack[index] = node
        // Bubble the change up to keep all ancestors current
        bubbleChangeUp(from: index)
        log("✅ After adding modifier - modifiers count: \(node.modifiers.count)")
        dbg("addModifier → completed. Node \(node.name.rawValue) now has \(node.modifiers.count) modifier(s).")
    }
    
    // Visit function call expressions (which represent view initializations and modifiers)
    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        log("Visiting function call: \(node.description)")
        log("Current stack depth: \(viewStack.count), current index: \(String(describing: currentNodeIndex))")
        
        if let identifierExpr = node.calledExpression.as(DeclReferenceExprSyntax.self) {
            // This might be a view initialization like Text("Hello")
            let viewName = identifierExpr.baseName.text
            
            guard let nameType = SyntaxViewName.from(viewName) else {
//                fatalErrorIfDebug("No view discovered for: \(viewName)")
                log("No view discovered for: \(viewName)")
                return .skipChildren
            }
            
            log("Found view initialization: \(viewName)")
            
            // Create a new ViewNode for this view
            let viewNode = SyntaxView(
                name: nameType,
                // This is creat
                constructorArguments: parseArgumentsForConstructor(from: node),
                modifiers: [],
                children: [],
                id: UUID()
            )
            
            log("Created new ViewNode for \(viewName) with \(viewNode.constructorArguments.count) arguments")
            
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
                    log("Adding \(viewName) as child to \(currentNode.name.rawValue)")
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
    private func parseArgumentsForConstructor(from node: FunctionCallExprSyntax) -> [SyntaxViewConstructorArgument] {
        
        let arguments = node.arguments.compactMap { (argument) -> SyntaxViewConstructorArgument? in
            
            guard let label = SyntaxConstructorArgumentLabel.from(argument.label?.text) else {
                // If we cannot
                log("could not create constructor argument label for argument.label: \(String(describing: argument.label))")
                return nil
            }
            
            
            let expr = argument.expression

            // Support either a single value or an array literal
            let syntaxKind = SyntaxArgumentKind.fromExpression(expr)
            let collectedValues: [SyntaxViewConstructorArgumentValue]
            if let arrayExpr = expr.as(ArrayExprSyntax.self) {
                collectedValues = arrayExpr.elements.map { element in
                    SyntaxViewConstructorArgumentValue(
                        value: element.expression.trimmedDescription,
                        syntaxKind: SyntaxArgumentKind.fromExpression(element.expression)
                    )
                }
            } else {
                collectedValues = [SyntaxViewConstructorArgumentValue(
                    value: expr.trimmedDescription,
                    syntaxKind: syntaxKind
                )]
            }

            return SyntaxViewConstructorArgument(
                label: label,
                values: collectedValues
            )
            
        }
        
        dbg("parseArguments → for \(node.calledExpression.trimmedDescription)  |  \(arguments.count) arg(s): \(arguments)")
        
        return arguments
    }
    
    // TODO: JULY 2: needed clearer entry-points for when we're parsing a view-modifier
    // Parse arguments from function call
    private func parseArgumentsForModifier(from node: FunctionCallExprSyntax) -> [SyntaxViewModifierArgument] {
        
        // Default handling for other modifiers
        let arguments = node.arguments.compactMap { (argument) -> SyntaxViewModifierArgument? in
            guard let label = SyntaxViewModifierArgumentLabel.from(argument.label?.text) else {
                log("could not create view modifier argument label for argument.label: \(String(describing: argument.label))")
                return nil
            }
            
            let expression = argument.expression
            let data = SyntaxViewModifierArgumentData(
                value: expression.trimmedDescription,
                syntaxKind: .fromExpression(expression)
            )
            return SyntaxViewModifierArgument(
                label: label,
                value: .simple(data)
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
    
    // MARK: - Modifier Handling
    
    /// Handles the rotation3DEffect modifier specially due to its complex argument structure
    private func handleRotation3DEffect(node: FunctionCallExprSyntax, name: SyntaxViewModifierName) {
        var arguments: [SyntaxViewModifierArgument] = []
        
        // Handle angle parameter (first argument: expected .degrees(...) or .radians(...))
        if let firstArg = node.arguments.first {
            let expr: ExprSyntax = firstArg.expression

            var angleArgument: SyntaxViewModifierArgumentAngle?

            // If the expression is a function call (e.g. .degrees(60) or .radians(x))
            if let call = expr.as(FunctionCallExprSyntax.self),
               let member = call.calledExpression.as(MemberAccessExprSyntax.self) {

                let fnName = member.declName.baseName.text   // "degrees" or "radians"

                // Extract the inner argument passed to .degrees/_radians
                if let innerExpr = call.arguments.first?.expression {
                    let valueString = innerExpr.trimmedDescription
                    let valueKind   = SyntaxArgumentKind.fromExpression(innerExpr)

                    switch fnName {
                    case "degrees":
                        angleArgument = .degrees(.init(value: valueString, syntaxKind: valueKind))
                    case "radians":
                        angleArgument = .radians(.init(value: valueString, syntaxKind: valueKind))
                    default:
                        break
                    }
                }
            }

            // Fallback: treat any other direct expression as degrees, preserving literal/variable/expr kind.
            if angleArgument == nil {
                let valueString = expr.trimmedDescription
                let valueKind   = SyntaxArgumentKind.fromExpression(expr)
                angleArgument = .degrees(.init(value: valueString, syntaxKind: valueKind))
            }

            // Append the constructed angle argument
            if let angleArgument = angleArgument {
                arguments.append(
                    SyntaxViewModifierArgument(
                        label: .noLabel,
                        value: .angle(angleArgument)
                    )
                )
            }
        }
        
        // Handle axis parameter
        if let axisArg = node.arguments.first(where: { $0.label?.text == "axis" }),
           let tupleExpr = axisArg.expression.as(TupleExprSyntax.self) {
            
            var xValue = "0", yValue = "0", zValue = "0"
            var xKind = SyntaxArgumentKind.literal(.float)
            var yKind = SyntaxArgumentKind.literal(.float)
            var zKind = SyntaxArgumentKind.literal(.float)
            
            for element in tupleExpr.elements {
                let expr = element.expression
                let value = expr.trimmedDescription
                let kind = SyntaxArgumentKind.fromExpression(expr)
                
                if element.label?.text == "x" {
                    xValue = value
                    xKind = kind
                } else if element.label?.text == "y" {
                    yValue = value
                    yKind = kind
                } else if element.label?.text == "z" {
                    zValue = value
                    zKind = kind
                }
            }
            
            let xData = SyntaxViewModifierArgumentData(value: xValue, syntaxKind: xKind)
            let yData = SyntaxViewModifierArgumentData(value: yValue, syntaxKind: yKind)
            let zData = SyntaxViewModifierArgumentData(value: zValue, syntaxKind: zKind)
            
            arguments.append(SyntaxViewModifierArgument(
                label: .axis,
                value: .axis(x: xData, y: yData, z: zData)
            ))
        }
        
        // Create and add the modifier
        let modifier = SyntaxViewModifier(
            name: name,
            arguments: arguments
        )
        addModifier(modifier)
    }
    
    /// Handles standard modifiers with generic argument parsing
    private func handleStandardModifier(node: FunctionCallExprSyntax, name: String) {
        let modifierArguments = parseArgumentsForModifier(from: node)
        
        var finalArgs = modifierArguments
        if finalArgs.isEmpty {
            // For modifiers with no arguments
            finalArgs = [
                SyntaxViewModifierArgument(
                    label: .noLabel,
                    value: .simple(SyntaxViewModifierArgumentData(
                        value: "",
                        syntaxKind: .literal(.unknown)
                    ))
                )
            ]
        }
        
        let modifier = SyntaxViewModifier(
            name: SyntaxViewModifierName(rawValue: name),
            arguments: finalArgs
        )
        addModifier(modifier)
    }
    
    // MARK: - SyntaxVisitor Overrides
    
    // When we finish visiting a node, manage the view stack
    override func visitPost(_ node: FunctionCallExprSyntax) {
        log("Visiting post for function call: \(node.description)")
        
        // Handle view initializations
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
                    log("  [\(index)] \(stackNode.name.rawValue) with \(stackNode.modifiers.count) modifiers")
                }
            }
            
            // We're exiting a view initialization
            if !viewStack.isEmpty {
                // Before removing the node, make sure we capture any modifiers that were added
                let lastNode = viewStack.last
                log("Node being popped: \(lastNode?.name.rawValue ?? "unknown") with \(lastNode?.modifiers.count ?? 0) modifiers")
                
                // Remove the last node
                viewStack.removeLast()
                
                // Update current node index to point to the new last node
                currentNodeIndex = viewStack.count > 0 ? viewStack.count - 1 : nil
                
                log("Stack after pop - depth: \(viewStack.count), new current index: \(String(describing: currentNodeIndex))")
                
                // Debug the root node state
                if let root = rootViewNode {
                    log("Root node: \(root.name.rawValue) with \(root.modifiers.count) modifiers and \(root.children.count) children")
                    if !root.children.isEmpty {
                        for (index, child) in root.children.enumerated() {
                            log("  Root child[\(index)]: \(child.name.rawValue) with \(child.modifiers.count) modifiers")
                        }
                    }
                }
            } else {
                log("View stack empty, nothing to pop")
            }
        }
        
 
        // ─────────────────────────────────────────────────────────────
        // Handle view‑modifier calls *after* the base view has been visited
        else if let modifierName = modifierNameIfViewModifier(node) {
            dbg("visitPost → handling view modifier '\(modifierName)'")
            
            let syntaxViewModifierName = SyntaxViewModifierName(rawValue: modifierName)
            if (syntaxViewModifierName == .rotationEffect
                || syntaxViewModifierName == .rotation3DEffect) {
                handleRotation3DEffect(node: node, name: syntaxViewModifierName)
            } else {
                handleStandardModifier(node: node, name: modifierName)
            }

            // If this FunctionCallExpr is not nested inside *another* MemberAccessExpr,
            // we are at the end of the modifier chain; pop the base view.
            if node.parent?.as(MemberAccessExprSyntax.self) == nil {
                if let popped = viewStack.popLast() {
                    dbg("visitPost → popped view \(popped.name.rawValue) after completing modifier chain")
                }
                currentNodeIndex = viewStack.isEmpty ? nil : viewStack.count - 1
            }
        }
    }
}

// Example usage function to test the parsing
func testSwiftUIToViewNode(swiftUICode: String) {
    if let viewNode = SwiftUIViewVisitor.parseSwiftUICode(swiftUICode) {
        print("\n==== PARSED VIEWNODE RESULT ====\n")
        print("Name: \(viewNode.name.rawValue)")
        print("Arguments: \(viewNode.constructorArguments)")
        print("Modifiers (\(viewNode.modifiers.count)):")
        for (index, modifier) in viewNode.modifiers.enumerated() {
            print("  [\(index)] \(modifier.name.rawValue))")
            if !modifier.arguments.isEmpty {
                print("    Arguments:")
                for arg in modifier.arguments {
                    print("      \(arg.label): \(arg.value)")
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
