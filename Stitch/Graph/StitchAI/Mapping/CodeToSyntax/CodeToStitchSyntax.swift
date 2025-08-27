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

/// Context for SwiftUI code parsing to control preprocessing behavior
enum ParseContext {
    case topLevel        // Normal parsing (apply VStack wrapping for multiple views)
    case overlayContent  // Overlay closure content (skip VStack wrapping)
    case scrollContent   // ScrollView or other container content
}

/// SwiftSyntax visitor that extracts ViewNode structure from SwiftUI code
final class SwiftUIViewVisitor: SyntaxVisitor {
    // Maps known patch nodes to a variable name
    let varNameIdMap: [String : String]
    
    init(varNameIdMap: [String : String]) {
        self.varNameIdMap = varNameIdMap
        super.init(viewMode: .sourceAccurate)
    }

    // Top-level declarations of patch data
    var bindingDeclarations = [String : SwiftParserInitializerType]()
    
    var viewStack: [SyntaxView] = []
    
    // Tracks decoding errors
    var caughtErrors: [SwiftUISyntaxError] = []
    
    override func visit(_ node: PatternBindingSyntax) -> SyntaxVisitorContinueKind {
        
        guard let identifierPattern = node.pattern.as(IdentifierPatternSyntax.self) else {
            return .visitChildren
        }
              
        let currentLHS = identifierPattern.identifier.text
        
        // Check for view builder (like var body)
        if let someOrAny = node.typeAnnotation?.type.as(SomeOrAnyTypeSyntax.self),
           someOrAny.constraint.trimmedDescription.contains("View"),
           let codeBlockListSyntax = node.accessorBlock?.accessors.as(CodeBlockItemListSyntax.self),
           let fnSyntax = codeBlockListSyntax.first?.item.as(FunctionCallExprSyntax.self) {
            if let view = self.visitLayerData(node: fnSyntax) {
                self.viewStack.append(view)
            }
            
            return .skipChildren
        }
        
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
            
            return .skipChildren
        }
        
        // Subscript callers used to access some node outputs
        else if let subscriptCallExpr = initializer.value.as(SubscriptCallExprSyntax.self) {
            // Subscript reference to some existing outputs
            let subscriptData = self.visitSubscriptData(subscriptCallExpr: subscriptCallExpr)
            self.bindingDeclarations
                .updateValue(subscriptData,
                             forKey: currentLHS)
            
            return .skipChildren
        }
        
        return .visitChildren
    }
    
    // Visit function call expressions (which represent view initializations and modifiers)
    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        // log("Visiting function call: \(node.description)")
        
        if let view = self.visitLayerData(node: node) {
            self.viewStack.append(view)

            // Skip children to avoid adding redundant data
            return .skipChildren
        }
        
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

    
    /// Parse for JS nodes.

    // TODO: we can probably remove this in favor of a FunctionDeclSyntax override?
    
    
    
    override func visit(_ node: MemberBlockItemSyntax) -> SyntaxVisitorContinueKind {
        // Checks for state variables
        if let varDeclSyntax = node.decl.as(VariableDeclSyntax.self) {
            guard varDeclSyntax.attributes.first?.as(AttributeSyntax.self)?.trimmedDescription == "@State",
                  varDeclSyntax.bindings.first.isDefined else {
                return .visitChildren
            }
            
            // If state variable, do nothing--we don't want this propagating
            return .skipChildren
        }
        
        // Checks for updateLayerInputs
        if let funcDeclSyntax = node.decl.as(FunctionDeclSyntax.self) {
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
                    self.bindingDeclarations.updateValue(.viewBuilder(bodyScript),
                                                         forKey: funcName)
                    
                    return .skipChildren
                }
                
                
                // JS node case
                else {
                    self.bindingDeclarations.updateValue(.jsNodeScript(bodyScript), forKey: funcName)
                    return .skipChildren
                }
            }
        }
        
        return .visitChildren
    }
    
    /// Ensures we only parse view structs.
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let inheritanceClause = node.inheritanceClause,
              inheritanceClause.inheritedTypes.contains(where: { $0.type.trimmedDescription.contains("View") }) else {
            return .skipChildren
        }
        return .visitChildren
    }
}

extension SwiftUIViewVisitor {
    /// Parses SwiftUI code into a ViewNode structure
    static func parseSwiftUICode(_ swiftUICode: String, context: ParseContext = .topLevel) -> SwiftUIViewParserResult {
//        log("\n==== PARSING CODE ====\n\(swiftUICode)\n=====================\n")
        
        var varNameIdMap = [String : String]()
        
        // Preprocess the code to ensure single root view in var body
        let preprocessedCode = preprocessSwiftUICode(swiftUICode, context: context)
        
        log("DEBUG: swiftUICode: \n\(swiftUICode)")
        log("DEBUG: preprocessedCode: \n\(preprocessedCode)")
        
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
    private static func preprocessSwiftUICode(_ code: String, context: ParseContext) -> String {
        // Only apply VStack wrapping for top-level parsing context
        guard context == .topLevel else {
            return code
        }
        
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
