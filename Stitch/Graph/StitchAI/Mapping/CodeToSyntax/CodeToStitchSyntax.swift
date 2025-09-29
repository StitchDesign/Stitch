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
    // Bypasses view parsing logic, used by some parsing helpers for gestures
    let willParseView: Bool
    let isStreaming: Bool
    
    init(willParseView: Bool, isStreaming: Bool = false) {
        self.willParseView = willParseView
        self.isStreaming = isStreaming
        super.init(viewMode: .sourceAccurate)
    }

    // Top-level declarations of patch data
    var bindingDeclarations = [(String, SwiftParserInitializerType)]()
    
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
            if let view = self.visitLayerData(node: fnSyntax,
                                              isStreaming: isStreaming) {
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
                fatalErrorIfDebug()
                log("visit: MAJOR ERROR with funcExpr -> self.visitPatchData")
                return .skipChildren
            }
            
            self.bindingDeclarations
                .append((currentLHS, .patchNode(patchNode)))
            
            return .skipChildren
        }
        
        // Subscript callers used to access some node outputs
        else if let subscriptCallExpr = initializer.value.as(SubscriptCallExprSyntax.self),
                // Subscript reference to some existing outputs
                let subscriptData = self.visitSubscriptData(subscriptCallExpr: subscriptCallExpr) {
            self.bindingDeclarations
                .append((currentLHS, subscriptData))
            
            return .skipChildren
        }
        
        return .visitChildren
    }
    
    // Visit function call expressions (which represent view initializations and modifiers)
    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        // log("Visiting function call: \(node.description)")
        guard willParseView else {
            return .visitChildren
        }
        
        if let view = self.visitLayerData(node: node,
                                          isStreaming: isStreaming) {
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
        let refName = refExpr.baseName.trimmedDescription
        
        if let subscriptExpr = assinmentElem.as(SubscriptCallExprSyntax.self),
           let subscriptRef = self.deriveSubscriptData(subscriptCallExpr: subscriptExpr, isStreaming: self.isStreaming) {
            self.bindingDeclarations
                .append((refName, .stateMutation(subscriptRef)))
            return .skipChildren
        }
        
        else if let declRefExpr = assinmentElem.as(DeclReferenceExprSyntax.self) {
            let declLabel = declRefExpr.baseName.trimmedDescription
            self.bindingDeclarations
                .append((refName, .stateMutation(.declrRef(declLabel))))
            return .skipChildren
        }
        
        // Captures arrays of PortValueDescription
        else if let arrayExpr = assinmentElem.as(ArrayExprSyntax.self) {
            self.bindingDeclarations
                .append((refName, .stateMutation(.arraySyntax(arrayExpr))))
            return .skipChildren
        }
        
        return .visitChildren
    }
    
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
                    self.bindingDeclarations.append((funcName, .viewBuilder(bodyScript)))
                    
                    return .skipChildren
                }
                
                
                // JS node case
                else {
                    self.bindingDeclarations.append((funcName, .jsNodeScript(bodyScript)))
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
    static func parseSwiftUICode(_ swiftUICode: String,
                                 context: ParseContext = .topLevel,
                                 willParseView: Bool = true,
                                 isStreaming: Bool = false) -> SwiftUIViewParserResult {
//        log("\n==== PARSING CODE ====\n\(swiftUICode)\n=====================\n")

        // First extract the struct from mixed text (handles LLM responses with explanations)
        let extractedCode = extractStructContentView(from: swiftUICode)

        // TODO: DO NOT FILTER OUT CONDITIONALS (`if`, ternary, etc.)
        // Remove conditional statements and ternary expressions
        let noConditionalsCode = removeConditionals(from: extractedCode)

        // Preprocess the code to ensure single root view in var body
        let preprocessedCode = preprocessSwiftUICode(noConditionalsCode, context: context)
        
        // log("DEBUG: swiftUICode: \n\(swiftUICode)")
        // log("DEBUG: preprocessedCode: \n\(preprocessedCode)")
        
        // Fall back to the original visitor-based approach for now
        // but add our own post-processing for modifiers
        let sourceFile = Parser.parse(source: preprocessedCode)
        
//#if DEV_DEBUG
//        print("\n==== DEBUG: SOURCE FILE STRUCTURE ====\n")
//        dump(sourceFile)
//        print("\n==== END DEBUG DUMP ====\n")
//#endif
        
        // Create a visitor that will extract the view structure
        let visitor = SwiftUIViewVisitor(willParseView: willParseView, isStreaming: isStreaming)
        visitor.walk(sourceFile)
                
        return .init(viewStack: visitor.viewStack,
                     bindingDeclarations: visitor.bindingDeclarations,
                     caughtErrors: visitor.caughtErrors)
    }
    
    /// Extracts struct ContentView from mixed text (handles LLM responses with explanatory text)
    private static func extractStructContentView(from text: String) -> String {
        // If the text already looks like clean Swift code (starts with struct), return as-is
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("struct ContentView: View") {
            return text
        }
        
        // Look for struct ContentView: View pattern
        guard let structRange = text.range(of: "struct ContentView: View") else {
            // No struct found, return original text (backward compatibility)
            return text
        }
        
        // Find the opening brace after "struct ContentView: View"
        let afterStruct = text[structRange.upperBound...]
        guard let openBraceRange = afterStruct.range(of: "{") else {
            return text
        }
        
        // Start extracting from "struct ContentView: View"
        let structStart = structRange.lowerBound
        let braceStart = openBraceRange.upperBound
        
        // Count braces to find the matching closing brace
        var braceCount = 1
        var inString = false
        var inSingleLineComment = false
        var inMultiLineComment = false
        var escapeNext = false
        
        var currentIndex = braceStart
        
        while currentIndex < text.endIndex && braceCount > 0 {
            let char = text[currentIndex]
            let nextIndex = text.index(after: currentIndex)
            
            // Handle escape sequences in strings
            if escapeNext {
                escapeNext = false
                currentIndex = nextIndex
                continue
            }
            
            // Check for comments and strings (ignore braces inside them)
            if !inString && !inSingleLineComment && !inMultiLineComment {
                // Check for comment starts
                if char == "/" && nextIndex < text.endIndex {
                    let nextChar = text[nextIndex]
                    if nextChar == "/" {
                        inSingleLineComment = true
                        currentIndex = text.index(after: nextIndex)
                        continue
                    } else if nextChar == "*" {
                        inMultiLineComment = true
                        currentIndex = text.index(after: nextIndex)
                        continue
                    }
                }
                
                // Check for string start
                if char == "\"" {
                    inString = true
                    currentIndex = nextIndex
                    continue
                }
                
                // Count braces
                if char == "{" {
                    braceCount += 1
                } else if char == "}" {
                    braceCount -= 1
                }
            } else if inString {
                // Handle string content
                if char == "\\" {
                    escapeNext = true
                } else if char == "\"" {
                    inString = false
                }
            } else if inSingleLineComment {
                // End single line comment at newline
                if char == "\n" {
                    inSingleLineComment = false
                }
            } else if inMultiLineComment {
                // End multi-line comment at */
                if char == "*" && nextIndex < text.endIndex && text[nextIndex] == "/" {
                    inMultiLineComment = false
                    currentIndex = text.index(after: nextIndex)
                    continue
                }
            }
            
            currentIndex = nextIndex
        }
        
        // If we found the matching brace, extract the complete struct
        if braceCount == 0 {
            let structEnd = currentIndex
            let extractedStruct = String(text[structStart..<structEnd])
            return extractedStruct
        }
        
        // If brace matching failed, return original text
        return text
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

    /// Removes conditional statements and ternary expressions from Swift code
    private static func removeConditionals(from code: String) -> String {
        let sourceFile = Parser.parse(source: code)
        let rewriter = ConditionalRemovalRewriter(viewMode: .sourceAccurate)
        let rewritten = rewriter.rewrite(sourceFile)
        return rewritten.description
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

