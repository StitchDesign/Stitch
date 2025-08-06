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

/// SwiftSyntax visitor that extracts ViewNode structure from SwiftUI code
final class SwiftUIViewVisitor: SyntaxVisitor {
    // Maps known patch nodes to a variable name
    let varNameIdMap: [String : String]
    
    init(varNameIdMap: [String : String]) {
        self.varNameIdMap = varNameIdMap
        super.init(viewMode: .sourceAccurate)
    }
    
    var rootViewNode: SyntaxView?
    
    // Top-level declarations of patch data
    var bindingDeclarations = [String : SwiftParserInitializerType]()
    
    var currentNodeIndex: Int? // Index into the view stack
    var viewStack: [SyntaxView] = []
    private var idCounter = 0
    
    // Context tracking for proper child vs argument parsing
    enum ParsingContext: Equatable {
        case root
        case closure(parentView: SyntaxViewName)
        case arguments
    }
    
    var contextStack: [ParsingContext] = [.root]
    
    // Tracks decoding errors
    var caughtErrors: [SwiftUISyntaxError] = []
    
    override func visit(_ node: PatternBindingSyntax) -> SyntaxVisitorContinueKind {
        
        guard let identifierPattern = node.pattern.as(IdentifierPatternSyntax.self) else {
            return .visitChildren
        }
              
        let currentLHS = identifierPattern.identifier.text
        
        // Record the name that's being bound (`let added = …`)
        guard let initializer = node.initializer else {
            return .visitChildren
        }
        
        // Patch node declaration cases
        if let funcExpr = initializer.value.as(FunctionCallExprSyntax.self) {
            // Assumed to be patch node
            guard let patchNode = self.visitPatchData(funcExpr,
                                                      varName: currentLHS) else {
                fatalError()
            }
            
            self.bindingDeclarations
                .updateValue(.patchNode(patchNode), forKey: currentLHS)
        }
        
        // Subscript callers used to access some node outputs
        else if let subscriptCallExpr = initializer.value.as(SubscriptCallExprSyntax.self) {
            // Subscript reference to some existing outputs
            let subscriptData = self.visitSubscriptData(subscriptCallExpr: subscriptCallExpr)
            self.bindingDeclarations
                .updateValue(.subscriptRef(subscriptData),
                             forKey: currentLHS)
        }

        else {
            // log("SwiftUIViewVisitor: unknown data at PatternBindingSyntax: \(node)")
//            fatalError()
        }
        
        return .visitChildren
    }
    
    // Visit function call expressions (which represent view initializations and modifiers)
    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        // log("Visiting function call: \(node.description)")
        // log("Current stack depth: \(viewStack.count), current index: \(String(describing: currentNodeIndex))")
        
        if let identifierExpr = node.calledExpression.as(DeclReferenceExprSyntax.self) {
            // log("LAYER DATA")
            
            return self.visitLayerData(identifierExpr: identifierExpr,
                                       node: node)
            
        } else if let memberAccessExpr = node.calledExpression.as(MemberAccessExprSyntax.self) {
            // Detected a modifier call (e.g. .padding()).  We *do not* attach the modifier
            // here because the base view may not have been pushed onto the stack yet.
            // Instead, we defer actual attachment to `visitPost(_:)`, which runs after the
            // base `FunctionCallExprSyntax` has been visited.
            // log("visit → encountered potential modifier .\(memberAccessExpr.declName.baseName.text) – deferring to visitPost")
        }
        
        return .visitChildren
    }
    
    // Tracks assignments to @State variables
    override func visit(_ node: SequenceExprSyntax) -> SyntaxVisitorContinueKind {
        let elements = Array(node.elements)

        guard elements.count == 3 else {
            fatalError()
        }
        
        guard let assignmentExpr = elements[1].as(AssignmentExprSyntax.self),
              assignmentExpr.trimmedDescription == "=" else {
            return .skipChildren
        }
        
        guard let refExpr = elements[0].as(DeclReferenceExprSyntax.self) else {
            return .skipChildren
        }
        
        let assinmentElem = elements[2]
        
        if let subscriptExpr = assinmentElem.as(SubscriptCallExprSyntax.self) {
            let subscriptRef = self.deriveSubscriptData(subscriptCallExpr: subscriptExpr)
            self.bindingDeclarations
                .updateValue(.stateMutation(.subscriptRef(subscriptRef)),
                             forKey: refExpr.baseName.trimmedDescription)
        }
        
        else if let declRefExpr = assinmentElem.as(DeclReferenceExprSyntax.self) {
            let declLabel = declRefExpr.baseName.trimmedDescription
            self.bindingDeclarations
                .updateValue(.stateMutation(.declrRef(declLabel)),
                             forKey: refExpr.baseName.trimmedDescription)
            
        }
        
        return .visitChildren
    }
    
    // Handle closure expressions (for container views like VStack, HStack, ZStack)
    override func visit(_ node: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
        // log("Entering closure expression")
        
        // Check if we're inside a container view that can have children
        if let currentView = currentViewNode, currentView.name.canHaveChildren {
            // log("Entering closure for container view: \(currentView.name.rawValue)")
            contextStack.append(.closure(parentView: currentView.name))
        } else {
            // log("Entering closure in non-container context (likely function arguments)")
            contextStack.append(.arguments)
        }
        
        return .visitChildren
    }
    
    override func visitPost(_ node: ClosureExprSyntax) {
        // log("Exiting closure expression")
        
        // Pop the context we pushed when entering the closure
        if contextStack.count > 1 {
            let poppedContext = contextStack.removeLast()
            // log("Popped context: \(poppedContext)")
        }
    }
    
    // MARK: - SyntaxVisitor Overrides
    
    // When we finish visiting a node, manage the view stack
    override func visitPost(_ node: FunctionCallExprSyntax) {
//        log("Visiting post for function call: \(node.description)")
        
        // Handle view initializations (constructor calls like `Rectangle()`, `Text("hello")`)
        if let identExpr = node.calledExpression.as(DeclReferenceExprSyntax.self) {
            let viewName = identExpr.baseName.text
//            log("Found view initialization: \(viewName)")
//            log("Current context stack: \(contextStack)")
//            log("Node parent type: \(type(of: node.parent))")
            
            // If this view call is the *base* of a MemberAccessExpr (e.g. Rectangle() in
            // Rectangle().frame(...)), we **keep** it on the stack so that the upcoming
            // modifier call can still access and mutate the current view node.
            if node.parent?.as(MemberAccessExprSyntax.self) != nil {
//                log("Deferring pop for \(viewName) because it is base of a modifier chain")
                return
            }
//            log("ViewStack before adjustment - count: \(viewStack.count), current node index: \(String(describing: currentNodeIndex))")
            
            // Debug the current stack state
            if !viewStack.isEmpty {
//                log("Current stack state:")
                for (index, stackNode) in viewStack.enumerated() {
//                    log("  [\(index)] \(stackNode.name.rawValue) with \(stackNode.modifiers.count) modifiers")
                }
            }
            
            // We're exiting a view initialization
            if let lastNode = viewStack.last,
               let nameType = SyntaxNameType.from(viewName),
               // Ensure a view here instead of a value
               nameType.isView {
                // Before removing the node, make sure we capture any modifiers that were added
//                log("Node being popped: \(lastNode.name.rawValue) with \(lastNode.modifiers.count) modifiers")
                
                // Remove the last node
                viewStack.removeLast()
                
                // Update current node index to point to the new last node
                currentNodeIndex = viewStack.count > 0 ? viewStack.count - 1 : nil
                
//                log("Stack after pop - depth: \(viewStack.count), new current index: \(String(describing: currentNodeIndex))")
                
                // Debug the root node state
                if let root = rootViewNode {
//                    log("Root node: \(root.name.rawValue) with \(root.modifiers.count) modifiers and \(root.children.count) children")
                    if !root.children.isEmpty {
                        for (index, child) in root.children.enumerated() {
//                            log("  Root child[\(index)]: \(child.name.rawValue) with \(child.modifiers.count) modifiers")
                        }
                    }
                }
            } else {
//                log("View stack empty, nothing to pop")
            }
        }
        
 
        // ─────────────────────────────────────────────────────────────
        // Handle view‑modifier calls *after* the base view has been visited
        else if let modifierName = modifierNameIfViewModifier(node) {
            // log("visitPost → handling view modifier '\(modifierName)'")
            
            if let syntaxViewModifierName = SyntaxViewModifierName(rawValue: modifierName) {
                    handleStandardModifier(node: node, modifierName: syntaxViewModifierName)
                
                // If this FunctionCallExpr is not nested inside *another* MemberAccessExpr,
                // we are at the end of the modifier chain; pop the base view.
                if node.parent?.as(MemberAccessExprSyntax.self) == nil {
                    if let popped = viewStack.popLast() {
                        // log("visitPost → popped view \(popped.name.rawValue) after completing modifier chain")
                    }
                    currentNodeIndex = viewStack.isEmpty ? nil : viewStack.count - 1
                }
            } else {
                // log("visitPost error: unable to parse view modifier name: \(modifierName)")
                self.caughtErrors.append(.unsupportedSyntaxViewModifierName(modifierName))
            }
        }
    }
}

extension SwiftUIViewVisitor {
    /// Parses SwiftUI code into a ViewNode structure
    static func parseSwiftUICode(_ swiftUICode: String,
                                 varNameIdMap: [String : String]) -> SwiftUIViewParserResult {
//        log("\n==== PARSING CODE ====\n\(swiftUICode)\n=====================\n")
        
        // Fall back to the original visitor-based approach for now
        // but add our own post-processing for modifiers
        let sourceFile = Parser.parse(source: swiftUICode)
        
//#if DEV_DEBUG
//        print("\n==== DEBUG: SOURCE FILE STRUCTURE ====\n")
//        dump(sourceFile)
//        print("\n==== END DEBUG DUMP ====\n")
//#endif
        
        // Create a visitor that will extract the view structure
        let visitor = SwiftUIViewVisitor(varNameIdMap: varNameIdMap)
        visitor.walk(sourceFile)
                
        return .init(rootView: visitor.rootViewNode,
                     bindingDeclarations: visitor.bindingDeclarations,
                     caughtErrors: visitor.caughtErrors)
    }
}
