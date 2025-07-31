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

struct SwiftUIViewParserResult {
    let rootView: SyntaxView?
    let bindingDeclarations: [String : SwiftParserInitializerType]
    let caughtErrors: [SwiftUISyntaxError]
}

extension SwiftUIViewVisitor {
    /// Parses SwiftUI code into a ViewNode structure
    static func parseSwiftUICode(_ swiftUICode: String) -> SwiftUIViewParserResult {
        print("\n==== PARSING CODE ====\n\(swiftUICode)\n=====================\n")
        
        // Fall back to the original visitor-based approach for now
        // but add our own post-processing for modifiers
        let sourceFile = Parser.parse(source: swiftUICode)
        
//#if DEV_DEBUG
//        print("\n==== DEBUG: SOURCE FILE STRUCTURE ====\n")
//        dump(sourceFile)
//        print("\n==== END DEBUG DUMP ====\n")
//#endif
        
        // Create a visitor that will extract the view structure
        let visitor = SwiftUIViewVisitor(viewMode: .sourceAccurate)
        visitor.walk(sourceFile)
                
        return .init(rootView: visitor.rootViewNode,
                     bindingDeclarations: visitor.bindingDeclarations,
                     caughtErrors: visitor.caughtErrors)
    }
}

/// SwiftSyntax visitor that extracts ViewNode structure from SwiftUI code
final class SwiftUIViewVisitor: SyntaxVisitor {
    var rootViewNode: SyntaxView?
    
    // Top-level declarations of patch data
    var bindingDeclarations = [String : SwiftParserInitializerType]()
    
    private var currentNodeIndex: Int? // Index into the view stack
    private var viewStack: [SyntaxView] = []
    private var idCounter = 0
    
    // Context tracking for proper child vs argument parsing
    private enum ParsingContext {
        case root
        case closure(parentView: SyntaxViewName)
        case arguments
    }
    private var contextStack: [ParsingContext] = [.root]
    
    // Tracks decoding errors
    var caughtErrors: [SwiftUISyntaxError] = []
    
    // Debug logging for tracing the parsing process
    private func log(_ message: String) {
//#if DEV_DEBUG
//        print("[SwiftUIParser] \(message)")
//#endif
    }
    
    private func dbg(_ message: String) {
//    #if DEV_DEBUG
//        print("🔍 [ModifierDebug] \(message)")
//    #endif
    }
    
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
            guard let patchNode = self.visitPatchData(funcExpr) else {
                fatalError()
            }
            
            self.bindingDeclarations
                .updateValue(.patchNode(patchNode), forKey: currentLHS)
        }
        
        // Subscript callers used to access some node outputs
        else if let subscriptCallExpr = initializer.value.as(SubscriptCallExprSyntax.self) {
            // Subscript reference to some existing outputs
            let subscriptRef = self.deriveSubscriptData(subscriptCallExpr: subscriptCallExpr)
            
            // Check for function expressions here too, needed for deriving patch data
            if let patchFn = subscriptCallExpr.calledExpression.as(FunctionCallExprSyntax.self) {
                // Assumed to be patch node
                guard let patchNode = self.visitPatchData(patchFn) else {
                    fatalError()
                }
                
                self.bindingDeclarations
                    .updateValue(.subscriptRef(.init(subscriptType: .patchNode(patchNode),
                                                     portIndex: subscriptRef.portIndex)),
                                 forKey: currentLHS)
            }
            
            else {
                self.bindingDeclarations.updateValue(.subscriptRef(subscriptRef),
                                                     forKey: currentLHS)
            }
        }
        
        // @State var cases
//        else if let identifierPatternSyntax = node.pattern.as(IdentifierPatternSyntax.self) {
//            self.bindingDeclarations.updateValue(.stateVarName,
//                                                 forKey: currentLHS)
//        }
        
        else {
            log("SwiftUIViewVisitor: unknown data at PatternBindingSyntax: \(node)")
//            fatalError()
        }
        
        
        return .visitChildren
    }
    
    // Visit function call expressions (which represent view initializations and modifiers)
    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        log("Visiting function call: \(node.description)")
        log("Current stack depth: \(viewStack.count), current index: \(String(describing: currentNodeIndex))")
        
        if let identifierExpr = node.calledExpression.as(DeclReferenceExprSyntax.self) {
            log("LAYER DATA")
            
            return self.visitLayerData(identifierExpr: identifierExpr,
                                       node: node)
            
        } else if let memberAccessExpr = node.calledExpression.as(MemberAccessExprSyntax.self) {
            // Detected a modifier call (e.g. .padding()).  We *do not* attach the modifier
            // here because the base view may not have been pushed onto the stack yet.
            // Instead, we defer actual attachment to `visitPost(_:)`, which runs after the
            // base `FunctionCallExprSyntax` has been visited.
            dbg("visit → encountered potential modifier .\(memberAccessExpr.declName.baseName.text) – deferring to visitPost")
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
        log("Entering closure expression")
        
        // Check if we're inside a container view that can have children
        if let currentView = currentViewNode, currentView.name.canHaveChildren {
            log("Entering closure for container view: \(currentView.name.rawValue)")
            contextStack.append(.closure(parentView: currentView.name))
        } else {
            log("Entering closure in non-container context (likely function arguments)")
            contextStack.append(.arguments)
        }
        
        return .visitChildren
    }
    
    override func visitPost(_ node: ClosureExprSyntax) {
        log("Exiting closure expression")
        
        // Pop the context we pushed when entering the closure
        if contextStack.count > 1 {
            let poppedContext = contextStack.removeLast()
            log("Popped context: \(poppedContext)")
        }
    }
    
    // MARK: - SyntaxVisitor Overrides
    
    // When we finish visiting a node, manage the view stack
    override func visitPost(_ node: FunctionCallExprSyntax) {
        log("Visiting post for function call: \(node.description)")
        
        // Handle view initializations (constructor calls like `Rectangle()`, `Text("hello")`)
        if let identExpr = node.calledExpression.as(DeclReferenceExprSyntax.self) {
            let viewName = identExpr.baseName.text
            log("Found view initialization: \(viewName)")
            log("Current context stack: \(contextStack)")
            log("Node parent type: \(type(of: node.parent))")
            
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
            if let lastNode = viewStack.last,
               let nameType = SyntaxNameType.from(viewName),
               // Ensure a view here instead of a value
               nameType.isView {
                // Before removing the node, make sure we capture any modifiers that were added
                log("Node being popped: \(lastNode.name.rawValue) with \(lastNode.modifiers.count) modifiers")
                
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
            
            if let syntaxViewModifierName = SyntaxViewModifierName(rawValue: modifierName) {
                    handleStandardModifier(node: node, modifierName: syntaxViewModifierName)
                
                // If this FunctionCallExpr is not nested inside *another* MemberAccessExpr,
                // we are at the end of the modifier chain; pop the base view.
                if node.parent?.as(MemberAccessExprSyntax.self) == nil {
                    if let popped = viewStack.popLast() {
                        dbg("visitPost → popped view \(popped.name.rawValue) after completing modifier chain")
                    }
                    currentNodeIndex = viewStack.isEmpty ? nil : viewStack.count - 1
                }
            } else {
                print("visitPost error: unable to parse view modifier name: \(modifierName)")
                self.caughtErrors.append(.unsupportedSyntaxViewModifierName(modifierName))
            }
        }
    }
}


// TODO: move utils
extension SwiftUIViewVisitor {
    // Parse arguments from function call
    func parseArguments(from node: FunctionCallExprSyntax) -> ViewConstructorType {
        // Default handling for other modifiers
        let arguments = node.arguments.compactMap { (argument) -> SyntaxViewArgumentData? in
            self.parseArgument(argument)
        }
        
        dbg("parseArguments → for \(node.calledExpression.trimmedDescription)  |  \(arguments.count) arg(s): \(arguments)")
        
        guard let knownViewConstructor = createKnownViewConstructor(
            from: node,
            arguments: arguments) else {
            return .other(arguments)
        }
        
        return .trackedConstructor(knownViewConstructor)
    }
    
    func parseArgument(_ argument: LabeledExprSyntax) -> SyntaxViewArgumentData? {
        let label = argument.label?.text
        
        let expression = argument.expression
        
        guard let value = self.parseArgumentType(from: expression) else {
            return nil
        }
        
        return .init(label: label,
                     value: value)
    }
    
    func parseFnArgumentType(_ funcExpr: FunctionCallExprSyntax) -> SyntaxViewModifierComplexType {
        // Recursively create argument data
        let complexTypeArgs = funcExpr.arguments
            .compactMap { expr in
                self.parseArgument(expr)
            }
        
        let complexType = SyntaxViewModifierComplexType(
            typeName: funcExpr.calledExpression.trimmedDescription,
            arguments: complexTypeArgs)
        
        return complexType
    }
    
    /// Handles conditional logic for determining a type of syntax argument.
    func parseArgumentType(from expression: SwiftSyntax.ExprSyntax) -> SyntaxViewModifierArgumentType? {
        // Handles compelx types, like PortValueDescription
        if let funcExpr = expression.as(FunctionCallExprSyntax.self) {
            let complexType = self.parseFnArgumentType(funcExpr)
            return .complex(complexType)
        }
        
        // Recursively handle arguments in tuple case
        else if let tupleExpr = expression.as(TupleExprSyntax.self) {
            let tupleArgs = tupleExpr.elements.compactMap(self.parseArgument(_:))
            return .tuple(tupleArgs)
        }
        
        // Recursively handle arguments in array case
        else if let arrayExpr = expression.as(ArrayExprSyntax.self) {
            let arrayArgs = arrayExpr.elements.compactMap {
                self.parseArgumentType(from: $0.expression)
            }
            return .array(arrayArgs)
        }
        
        else if let memberAccessExpr = expression.as(MemberAccessExprSyntax.self) {
            return .memberAccess(SyntaxViewMemberAccess(
                base: memberAccessExpr.base?.trimmedDescription,
                property: memberAccessExpr.declName.baseName.trimmedDescription))
            
        }
        
        else if let dictExpr = expression.as(DictionaryExprSyntax.self) {
            // Break down children
            let dictChildren = dictExpr.content.children(viewMode: .sourceAccurate)
            let recursedChildren = dictChildren.compactMap { dictElem -> SyntaxViewArgumentData? in
                guard let dictElem = dictElem.as(DictionaryElementSyntax.self),
                      // get value data recursively
                      let value = self.parseArgumentType(from: dictElem.value) else {
                    return nil
                }
                
                let label = dictElem.key.trimmedDescription
                return SyntaxViewArgumentData(label: label, value: value)
            }
            
            // Testing tuple type for now, should be the same stuff
            return .tuple(recursedChildren)
        }
        
        // Tracks references to state
        else if let declrRefExpr = expression.as(DeclReferenceExprSyntax.self) {
            return .stateAccess(declrRefExpr.trimmedDescription)
        }
        
        guard let syntaxKind = SyntaxArgumentKind.fromExpression(expression) else {
            self.caughtErrors.append(.unsupportedSyntaxArgumentKind(expression.trimmedDescription))
            return nil
        }
        
        switch syntaxKind {
        case .literal(let syntaxArgumentLiteralKind):
            // Simple case
            let data = SyntaxViewSimpleData(
                value: expression.trimmedDescription,
                syntaxKind: syntaxArgumentLiteralKind
            )
            return .simple(data)
            
        default:
            // No support for variables or expressions here
            return nil
        }
    }
    
}


// TODO: move layer helpers

extension SwiftUIViewVisitor {
    func visitLayerData(identifierExpr: DeclReferenceExprSyntax,
                        node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        // This might be a view initialization like Text("Hello")
        let viewName = identifierExpr.baseName.text
        
        guard let nameType = SyntaxNameType.from(viewName) else {
//                fatalErrorIfDebug("No view discovered for: \(viewName)")
            log("No concept discovered for: \(viewName)")
            
            // Tracks for later silent failures
            self.caughtErrors.append(.unsupportedSyntaxViewName(viewName))
            
            return .skipChildren
        }
        
        log("Found view initialization: \(viewName)")
        
        // Parse args, catching arguments we don't yet support
        let args = self.parseArguments(from: node)
        
        switch nameType {
        case .view(let syntaxViewName):
            // Create a new ViewNode for this view
            let viewNode = SyntaxView(
                name: syntaxViewName,
                // This is creat
                constructorArguments: args,
                modifiers: [],
                children: [],
                id: UUID()
                //                errors: self.caughtErrors
            )
            
            log("Created new ViewNode for \(viewName)")
            
            // Set as root or add as child to current node (context-aware)
            if viewStack.isEmpty {
                log("Setting as root ViewNode: \(viewName)")
                viewStack.append(viewNode)
                currentNodeIndex = 0
                rootViewNode = viewNode

                log("Current node index set to: \(String(describing: currentNodeIndex))")
            } else {
                // Check if this view initialization should be treated as a child
                // Only apply context-aware logic for top-level view statements that could be children
                let currentContext = contextStack.last ?? .root
                log("Current parsing context: \(currentContext)")
                
                switch currentContext {
                case .closure(let parentViewName):
                    // We're inside a closure of a container view - this IS a legitimate child
                    if let currentNode = currentViewNode {
                        log("Adding \(viewName) as child to \(currentNode.name.rawValue) (inside closure)")
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
                    
                case .arguments, .root:
                    // We're parsing function arguments - this might be a modifier argument
                    // Check if this is actually being used as a modifier argument
                    if isWithinModifierArguments(node) {
                        log("Found view \(viewName) in modifier argument context - allowing normal processing")
                        // For modifier arguments, we still need to process the view normally
                        // but we don't add it as a child to any parent view
                        // Just add it to the stack temporarily so it can be processed
                        viewStack.append(viewNode)
                        currentNodeIndex = viewStack.count - 1
                    } else {
                        log("⚠️ Found view \(viewName) in argument context - skipping child addition")
                        log("This view should be handled as an argument, not as a child")
                        // Don't add to viewStack - this prevents it from being treated as a child
                    }
                }
            }
            
            return .visitChildren
            
        case .value:
            // No view here, just continue
            return .skipChildren
        }
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
        guard
            // Must look like `.something`  (i.e. a MemberAccessExpr)
            let member = node.calledExpression.as(MemberAccessExprSyntax.self),
            let base   = member.base            // no base ⇒ e.g. `.degrees(90)` helper
        else {
            return nil
        }
        
        /// Walks the `base` chain and returns `true` iff we eventually hit a
        /// `FunctionCallExprSyntax` (e.g. `Rectangle()` or `Color.red`), meaning
        /// the member access is **chained onto a view instance**.  Static helper
        /// calls such as `Double.random(in:)` terminate in an `IdentifierExpr`
        /// (“Double”) and therefore return `false`.
        func isChainedToView(_ syntax: SyntaxProtocol) -> Bool {
            if syntax.is(FunctionCallExprSyntax.self) { return true }
            if let m = syntax.as(MemberAccessExprSyntax.self), let inner = m.base {
                return isChainedToView(inner)
            }
            return false
        }

        return isChainedToView(base) ? member.declName.baseName.text : nil
    }
    
    /// Check if this function call is within the arguments of a modifier
    /// This helps distinguish between legitimate child views and modifier arguments
    private func isWithinModifierArguments(_ node: FunctionCallExprSyntax) -> Bool {
        // Walk up the parent chain to see if we're inside a modifier's argument list
        var currentNode: Syntax? = node.parent
        
        while let parent = currentNode {
            // If we find a FunctionCallExprSyntax that is a modifier, and we're in its arguments
            if let functionCall = parent.as(FunctionCallExprSyntax.self),
               modifierNameIfViewModifier(functionCall) != nil {
                // We're inside a modifier's argument list
                return true
            }
            currentNode = parent.parent
        }
        
        return false
    }
    
    /// Propagate a mutation at `index` upward through `viewStack`
    /// so that every ancestor’s `children` array is updated
    /// and `rootViewNode` stays in sync.
    private func bubbleChangeUp(from index: Int) {
        var childIndex = index
        while childIndex > 0 {
            let parentIndex = childIndex - 1
            var parent = viewStack[parentIndex]
            let child = viewStack[childIndex]
            
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

    /// Handles standard modifiers with generic argument parsing
    private func handleStandardModifier(node: FunctionCallExprSyntax,
                                        modifierName: SyntaxViewModifierName) {
        let modifierArguments = self.parseArguments(from: node)
        
        let modifier = SyntaxViewModifier(
            name: modifierName,
            arguments: modifierArguments
        )
        addModifier(modifier)
    }
}

//// Example usage function to test the parsing
//func testSwiftUIToViewNode(swiftUICode: String) {
//    if let viewNode = SwiftUIViewVisitor.parseSwiftUICode(swiftUICode) {
//        print("\n==== PARSED VIEWNODE RESULT ====\n")
//        print("Name: \(viewNode.name.rawValue)")
//        print("Arguments: \(viewNode.constructorArguments)")
//        print("Modifiers (\(viewNode.modifiers.count)):")
//        for (index, modifier) in viewNode.modifiers.enumerated() {
//            print("  [\(index)] \(modifier.name.rawValue))")
//            if !modifier.arguments.isEmpty {
//                print("    Arguments:")
//                for arg in modifier.arguments {
//                    print("      \(arg.label): \(arg.value)")
//                }
//            }
//        }
//        print("Children: \(viewNode.children.count)")
//        print("============================\n")
//    } else {
//        print("Failed to parse SwiftUI code")
//    }
//}
//
//// Run a simple test with a Text view that has modifiers
//func runModifierParsingTest() {
//    print("\n==== TESTING MODIFIER PARSING ====\n")
//
//    let testCode = "Text(\"Hello\").foregroundColor(.blue).padding()"
//    print("Test code: \(testCode)")
//
//    testSwiftUIToViewNode(swiftUICode: testCode)
//
//    print("\n==== TEST COMPLETE ====\n")
//}


// TODO: move

extension SwiftUIViewVisitor {
    func visitPatchData(_ node: FunctionCallExprSyntax) -> SwiftParserPatchData? {
        guard
            let subscriptExpr = node.calledExpression.as(SubscriptCallExprSyntax.self),
            let baseIdent = subscriptExpr.calledExpression.as(DeclReferenceExprSyntax.self),
            baseIdent.baseName.text == "NATIVE_STITCH_PATCH_FUNCTIONS",
            let firstArg = subscriptExpr.arguments.first,
            let stringLit = firstArg.expression.as(StringLiteralExprSyntax.self)
        else {
            return nil
        }
        
        guard let patchNode = stringLit.segments.first?.description else {
            return nil
        }
        
//        self.patchNodesByVarName
//            .updateValue(patchNode, forKey: currentLHS)
        
        guard let elements = node.arguments.first?.expression.as(ArrayExprSyntax.self)?.elements else {
            fatalErrorIfDebug()
            return nil
        }
        
        let patchNodeArgs = elements.compactMap { arg -> SwiftParserPatternBindingArg? in
            // ArrayExpr → might hold a PortValueDescription literal
            if let arrayElem = arg.expression.as(ArrayExprSyntax.self),
               let innerFirstElem = arrayElem.elements.first?.expression {
                
                guard let argData = self.parseArgumentType(from: innerFirstElem) else {
                    fatalError()
                }
                
                return .value(argData)
            }
            
            else if let declrRefSyntax = arg.expression.as(DeclReferenceExprSyntax.self) {
                print("Input param that points to some reference: \(declrRefSyntax)")
                return .binding(declrRefSyntax)
            }
            
            else {
                fatalError()
            }
        }
        
        return .init(patchName: patchNode,
                     args: patchNodeArgs)
    }
}

enum SwiftParserPatternBindingArg {
    case value(SyntaxViewModifierArgumentType)
    case binding(DeclReferenceExprSyntax)
}

struct SwiftParserPatchData {
    // TODO: must be decoded
    let id = UUID().uuidString
    
    var patchName: String
    var args: [SwiftParserPatternBindingArg]
}

struct SwiftParserSubscript {
    // The name of the variable
    var subscriptType: SwiftParserSubscriptType
    var portIndex: Int
}

enum SwiftParserInitializerType {
    // creates some patch node from a declared function
    case patchNode(SwiftParserPatchData)
    
    // access an index of some node's outputs
    case subscriptRef(SwiftParserSubscript)
    
    // initializes state
//    case stateVarName
    
    // mutates some existing state
    case stateMutation(SwiftParserStateMutation)
}

enum SwiftParserStateMutation {
    case declrRef(String)
    case subscriptRef(SwiftParserSubscript)
}

// Subscripts can be used on references or nodes themselves
enum SwiftParserSubscriptType {
    case ref(String)
    case patchNode(SwiftParserPatchData)
}

extension SwiftParserPatchData {
    func createStitchData(varName: String,
                          varNameIdMap: inout [String : String]) -> CurrentAIGraphData.NativePatchNode {
        guard let patchName = CurrentAIGraphData.StitchAIPatchOrLayer.init(value: .init(self.patchName)) else {
            fatalError()
        }
        
//        let nodeIdString = String(varName.split(separator: "_")[safe: 1] ?? "")
//        let decodedId = UUID(uuidString: nodeIdString) ?? .init()
        varNameIdMap.updateValue(self.id, forKey: varName)
        
        let newPatchNode = CurrentAIGraphData
            .NativePatchNode(node_id: self.id,
                             node_name: patchName)
        return newPatchNode
    }
}

// TODO: move
extension SwiftParserPatchData {
    static func derivePatchUpstreamCoordinate(upstreamRefData: SwiftParserSubscript,
                                              varNameIdMap: [String : String]) -> AIGraphData_V0.NodeIndexedCoordinate {
        let upstreamPortIndex = upstreamRefData.portIndex
        let upstreamNodeId: String
        
        // Get upstream node ID
        switch upstreamRefData.subscriptType {
        case .patchNode(let patchNodeData):
            upstreamNodeId = patchNodeData.id
            
        case .ref(let refName):
            guard let _upstreamNodeId = varNameIdMap.get(refName) else {
                fatalError()
            }
            
            upstreamNodeId = _upstreamNodeId
        }
        
        return .init(node_id: upstreamNodeId,
                     port_index: upstreamPortIndex)
    }
}

// TODO: move
extension SwiftUIViewVisitor {
    func deriveSubscriptData(subscriptCallExpr: SubscriptCallExprSyntax) -> SwiftParserSubscript {
        guard let labeledExpr = subscriptCallExpr.arguments.first?.expression.as(IntegerLiteralExprSyntax.self),
              let portIndex = Int(labeledExpr.literal.text) else {
            fatalError()
        }
        
        // Patch declarations can call here too
        if let funcExpr = subscriptCallExpr.calledExpression.as(FunctionCallExprSyntax.self) {
            guard let patchNode = self.visitPatchData(funcExpr) else {
                fatalError()
            }
            
            let subscriptRef = SwiftParserSubscript(subscriptType: .patchNode(patchNode),
                                                    portIndex: portIndex)
            
            return subscriptRef
        }
        
        // Output port index access of some patch node in the form of index access of a patch fn's output values
        else if let declRef = subscriptCallExpr.calledExpression.as(DeclReferenceExprSyntax.self) {
            
            let outputPortData = SwiftParserSubscript(subscriptType: .ref(declRef.baseName.text),
                                                      portIndex: portIndex)
            
            return outputPortData
        }
        
        else {
            fatalError()
        }
    }
}

extension SwiftParserInitializerType {
    func parseStitchActions(varName: String,
                            varNameIdMap: [String : String],
                            varNameOutputPortMap: [String : SwiftParserSubscript],
    customPatchInputValues: inout [CurrentAIGraphData.CustomPatchInputValue],
                            patchConnections: inout [CurrentAIGraphData.PatchConnection],
                            viewStatePatchConnections: inout [String : AIGraphData_V0.NodeIndexedCoordinate]) throws {
        switch self {
        case .patchNode(let patchNodeData):
            for (portIndex, arg) in patchNodeData.args.enumerated() {
                switch arg {
                case .binding(let declRefSyntax):
                    // Get edge data
                    let refName = declRefSyntax.baseName.text
                                            
                    guard let upstreamRefData = varNameOutputPortMap.get(refName) else {
                        fatalError()
                    }
                    
                    let usptreamCoordinate = SwiftParserPatchData
                        .derivePatchUpstreamCoordinate(upstreamRefData: upstreamRefData,
                                                       varNameIdMap: varNameIdMap)
                    
                    patchConnections.append(
                        .init(src_port: usptreamCoordinate,
                              dest_port: .init(node_id: patchNodeData.id,                          port_index: portIndex))
                    )
                    
                case .value(let argType):
                    let portDataList = try argType.derivePortValues()
                    
                    for portData in portDataList {
                        switch portData {
                        case .value(let portValue):
                            customPatchInputValues.append(
                                .init(patch_input_coordinate: .init(
                                    node_id: patchNodeData.id,
                                    port_index: portIndex),
                                      value: portValue.value,
                                      value_type: portValue.value_type)
                            )
                            
                        case .stateRef(let string):
                            fatalErrorIfDebug("State variables should never be passed into patch nodes")
                            throw SwiftUISyntaxError.unsupportedStateInPatchInputParsing(patchNodeData)
                        }
                    }
                }
            }
            
        case .stateMutation(let mutationData):
            let subscriptData: SwiftParserSubscript
            
            // Find subscript data which must exist for view state mutation
            switch mutationData {
            case .subscriptRef(let _subscriptData):
                subscriptData = _subscriptData
                
            case .declrRef(let ref):
                guard let refData = varNameOutputPortMap.get(ref) else {
                    throw SwiftUISyntaxError.unexpectedStateMutatorFound(mutationData)
                }
                
                subscriptData = refData
            }
            
            // Track upstream patch coordinate to some TBD layer input
            let usptreamCoordinate = SwiftParserPatchData
                .derivePatchUpstreamCoordinate(upstreamRefData: subscriptData,
                                               varNameIdMap: varNameIdMap)
            
            viewStatePatchConnections.updateValue(usptreamCoordinate,
                                                  forKey: varName)
            
        case .subscriptRef(let subscriptData):
            switch subscriptData.subscriptType {
            case .patchNode(let patchNodeData):
                let initializerData = SwiftParserInitializerType.patchNode(patchNodeData)
                
                // Recursively parse patch node data
                try initializerData
                    .parseStitchActions(varName: varName,
                                        varNameIdMap: varNameIdMap,
                                        varNameOutputPortMap: varNameOutputPortMap,
                                        customPatchInputValues: &customPatchInputValues,
                                        patchConnections: &patchConnections,
                                        viewStatePatchConnections: &viewStatePatchConnections)
                
            case .ref:
                // Ignore here
                return
            }
        }
    }
}
