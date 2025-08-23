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
    
    // Captures context for parsing, no longer used as a return value
//    private var rootViewNode: SyntaxView?
    
    // Top-level declarations of patch data
    var bindingDeclarations = [String : SwiftParserInitializerType]()
    
//    var currentNodeIndex: Int? // Index into the view stack
    var viewStack: [SyntaxView] = []
    
//    var currentView: SyntaxView?
    
//    private var idCounter = 0
    
    // Context tracking for proper child vs argument parsing
//    enum ParsingContext: Equatable {
////        case root
//        case closure(parentView: SyntaxViewName)
//        case arguments
//    }
    
//    var contextStack: [ParsingContext] = [.root]
    
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
                .updateValue(subscriptData,
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
            
            // TODO: consider how visitLayerData works with functions not yet known. do we bubble up info to root node as a preprocessed thing?
            
            if let node = self.visitLayerData(node: node) {
                self.viewStack.append(node)
            }

            return .skipChildren
        }
//        else if let memberAccessExpr = node.calledExpression.as(MemberAccessExprSyntax.self) {
            // Detected a modifier call (e.g. .padding()).  We *do not* attach the modifier
            // here because the base view may not have been pushed onto the stack yet.
            // Instead, we defer actual attachment to `visitPost(_:)`, which runs after the
            // base `FunctionCallExprSyntax` has been visited.
            // log("visit → encountered potential modifier .\(memberAccessExpr.declName.baseName.text) – deferring to visitPost")
//        }
        
        return .visitChildren
    }
    
    // Tracks assignments to @State variables
    override func visit(_ node: SequenceExprSyntax) -> SyntaxVisitorContinueKind {
        let elements = Array(node.elements)

        guard elements.count == 3 else {
            // Comes up from conditionals using `??`, just ignore
            return .skipChildren
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
                .updateValue(.stateMutation(subscriptRef),
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
    
//    // Handle closure expressions (for container views like VStack, HStack, ZStack)
//    override func visit(_ node: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
//        // log("Entering closure expression")
//        
//        // Check if we're inside a container view that can have children
//        if let currentView = self.currentView, currentView.name.canHaveChildren {
//            // log("Entering closure for container view: \(currentView.name.rawValue)")
//            contextStack.append(.closure(parentView: currentView.name))
//        } else {
//            // log("Entering closure in non-container context (likely function arguments)")
//            contextStack.append(.arguments)
//        }
//        
//        return .visitChildren
//    }
    
    /// Parse for JS nodes.

    // TODO: we can probably remove this in favor of a FunctionDeclSyntax override?
    
    
    
    override func visit(_ node: MemberBlockItemSyntax) -> SyntaxVisitorContinueKind {
        guard let funcDeclSyntax = node.decl.as(FunctionDeclSyntax.self) else {
            return .visitChildren
        }
        
        if funcDeclSyntax.name.text == "updateLayerInputs" {
            return .visitChildren
        }
        
        else {
            guard let body = funcDeclSyntax.body else {
                return .visitChildren
            }
            
            let funcName = funcDeclSyntax.name.text
            let bodyScript = body.description.trimmingOuterBraces()

            // View builder function
            if let someOrAnyReturnType = funcDeclSyntax.signature.returnClause?.type.as(SomeOrAnyTypeSyntax.self),
               someOrAnyReturnType.constraint.trimmedDescription == "View" {
                
                // Create new visitor class
                let parseResult = SwiftUIViewVisitor.parseSwiftUICode(bodyScript,
                                                                      varNameIdMap: self.varNameIdMap)
                
                if let syntaxView = parseResult.viewStack.first {
                    assertInDebug(parseResult.viewStack.count == 1)
                    
                    self.bindingDeclarations.updateValue(.viewBuilder(syntaxView),
                                                         forKey: funcName)
                }
                
                return .skipChildren
            }
            

            // JS node case
            else {
                self.bindingDeclarations.updateValue(.jsNodeScript(bodyScript), forKey: funcName)
                return .skipChildren
            }
        }
    }
    
    /// Ensures we only parse view structs.
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let inheritanceClause = node.inheritanceClause,
              inheritanceClause.inheritedTypes.contains(where: { $0.type.trimmedDescription == "View" }) else {
            return .skipChildren
        }
        return .visitChildren
    }
    
//    override func visitPost(_ node: ClosureExprSyntax) {
//        // log("Exiting closure expression")
//        
//        // Pop the context we pushed when entering the closure
//        if contextStack.count > 1 {
//            let poppedContext = contextStack.removeLast()
//            // log("Popped context: \(poppedContext)")
//        }
//    }
    
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
//            if !viewStack.isEmpty {
////                log("Current stack state:")
//                for (index, stackNode) in viewStack.enumerated() {
////                    log("  [\(index)] \(stackNode.name.rawValue) with \(stackNode.modifiers.count) modifiers")
//                }
//            }
            
            // We're exiting a view initialization
//            if let lastNode = self.currentView,
//               let nameType = SyntaxNameType.from(viewName),
//               // Ensure a view here instead of a value
//               nameType.isView {
//                // Before removing the node, make sure we capture any modifiers that were added
////                log("Node being popped: \(lastNode.name.rawValue) with \(lastNode.modifiers.count) modifiers")
//                
//                // Update the view stack
//                viewStack.append(lastNode)
//                
//                // Update current node index to point to the new last node
////                currentNodeIndex = viewStack.count > 0 ? viewStack.count - 1 : nil
//                
////                log("Stack after pop - depth: \(viewStack.count), new current index: \(String(describing: currentNodeIndex))")
//                
//                // Debug the root node state
////                if let root = rootViewNode {
//////                    log("Root node: \(root.name.rawValue) with \(root.modifiers.count) modifiers and \(root.children.count) children")
////                    if !root.children.isEmpty {
////                        for (index, child) in root.children.enumerated() {
//////                            log("  Root child[\(index)]: \(child.name.rawValue) with \(child.modifiers.count) modifiers")
////                        }
////                    }
////                }
//            } else {
////                log("View stack empty, nothing to pop")
//            }
        }
        
 
        // ─────────────────────────────────────────────────────────────
        // Handle view‑modifier calls *after* the base view has been visited
        else if let modifierName = modifierNameIfViewModifier(node) {
            // log("visitPost → handling view modifier '\(modifierName)'")
            
            if let syntaxViewModifierName = SyntaxViewModifierName(rawValue: modifierName) {
                    handleStandardModifier(node: node, modifierName: syntaxViewModifierName)
                
                // If this FunctionCallExpr is not nested inside *another* MemberAccessExpr,
                // we are at the end of the modifier chain; pop the base view.
//                if node.parent?.as(MemberAccessExprSyntax.self) == nil {
//                    if let popped = viewStack.popLast() {
//                        // log("visitPost → popped view \(popped.name.rawValue) after completing modifier chain")
//                    }
//                    currentNodeIndex = viewStack.isEmpty ? nil : viewStack.count - 1
//                }
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
        
        // Preprocess the code to ensure single root view in var body
        let preprocessedCode = preprocessSwiftUICode(swiftUICode)
        
//        log("DEBUG: swiftUICode: \n\(swiftUICode)")
//        log("DEBUG: preprocessedCode: \n\(preprocessedCode)")
        
        // Fall back to the original visitor-based approach for now
        // but add our own post-processing for modifiers
        let sourceFile = Parser.parse(source: preprocessedCode)
        
//#if DEV_DEBUG
//        print("\n==== DEBUG: SOURCE FILE STRUCTURE ====\n")
//        dump(sourceFile)
//        print("\n==== END DEBUG DUMP ====\n")
//#endif
        
        // Create a visitor that will extract the view structure
        let visitor = SwiftUIViewVisitor(varNameIdMap: varNameIdMap)
        visitor.walk(sourceFile)
                
        return .init(viewStack: visitor.viewStack,
                     bindingDeclarations: visitor.bindingDeclarations,
                     caughtErrors: visitor.caughtErrors)
    }
    
    /// Preprocesses SwiftUI code to wrap multiple top-level views in var body with VStack
    private static func preprocessSwiftUICode(_ code: String) -> String {
        // Simple approach: if the code doesn't have var body, it's just raw views - wrap them
        if !code.contains("var body") {
            // Count top-level SwiftUI view declarations
            let topLevelViewCount = countTopLevelViewDeclarations(in: code)
            
            if topLevelViewCount > 1 {
                // Multiple top-level views - wrap in VStack  
                let indentedContent = code.components(separatedBy: .newlines)
                    .map { line in line.isEmpty ? line : "    \(line)" }
                    .joined(separator: "\n")
                return "VStack {\n\(indentedContent)\n}"
            }
        }
        
        return code
    }
    
    /// Counts actual top-level SwiftUI view declarations (not lines)
    private static func countTopLevelViewDeclarations(in code: String) -> Int {
        let swiftUIViews = ["Text", "Rectangle", "Ellipse", "Circle", "Image", "VStack", "HStack", "ZStack", "ScrollView", "Button"]
        var count = 0
        var braceDepth = 0
        var inString = false
        var escapeNext = false
        
        var i = code.startIndex
        while i < code.endIndex {
            let char = code[i]
            
            // Handle string literals
            if escapeNext {
                escapeNext = false
            } else if char == "\\" && inString {
                escapeNext = true
            } else if char == "\"" {
                inString.toggle()
            } else if !inString {
                // Track brace depth to know when we're at top level
                if char == "{" {
                    braceDepth += 1
                } else if char == "}" {
                    braceDepth -= 1
                }
                
                // Check for SwiftUI view at top level (braceDepth == 0)
                if braceDepth == 0 {
                    for viewName in swiftUIViews {
                        if code[i...].hasPrefix(viewName + "(") || code[i...].hasPrefix(viewName + " {") {
                            count += 1
                            break
                        }
                    }
                }
            }
            
            i = code.index(after: i)
        }
        
        return count
    }
}

extension String {
    func trimmingOuterBraces() -> String {
        // Trim leading/trailing whitespace and newlines first
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmed.hasPrefix("{"), trimmed.hasSuffix("}") else {
            // No outer braces, return original
            return self
        }
        
        // Remove first and last character
        let start = trimmed.index(after: trimmed.startIndex)
        let end = trimmed.index(before: trimmed.endIndex)
        return String(trimmed[start..<end])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
