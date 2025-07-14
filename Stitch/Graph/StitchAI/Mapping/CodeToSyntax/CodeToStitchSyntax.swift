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
    let caughtErrors: [SwiftUISyntaxError]
}

extension SwiftUIViewVisitor {
    /// Parses SwiftUI code into a ViewNode structure
    static func parseSwiftUICode(_ swiftUICode: String) -> SwiftUIViewParserResult {
        print("\n==== PARSING CODE ====\n\(swiftUICode)\n=====================\n")
        
        // Fall back to the original visitor-based approach for now
        // but add our own post-processing for modifiers
        let sourceFile = Parser.parse(source: swiftUICode)
        
#if DEV_DEBUG
        print("\n==== DEBUG: SOURCE FILE STRUCTURE ====\n")
        dump(sourceFile)
        print("\n==== END DEBUG DUMP ====\n")
#endif
        
        // Create a visitor that will extract the view structure
        let visitor = SwiftUIViewVisitor(viewMode: .sourceAccurate)
        visitor.walk(sourceFile)
                
        return .init(rootView: visitor.rootViewNode,
                     caughtErrors: visitor.caughtErrors)
    }
}

/// SwiftSyntax visitor that extracts ViewNode structure from SwiftUI code
final class SwiftUIViewVisitor: SyntaxVisitor {
    var rootViewNode: SyntaxView?
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
#if DEV_DEBUG
        print("[SwiftUIParser] \(message)")
#endif
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
        
    // MARK: - Attach strongly-typed constructor
    /// Adds a `ViewConstructor` to the *current* SyntaxView and keeps the
    /// root/ancestors in sync.
//    private func attachConstructor(_ ctor: ViewConstructor) {
//        guard let idx = currentNodeIndex, idx < viewStack.count else { return }
//        var node = viewStack[idx]
//        node.constructor = ctor          // ⇐ requires `var constructor: ViewConstructor?` on SyntaxView
//        viewStack[idx] = node
//        bubbleChangeUp(from: idx)
//    }
    
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
    
    /// Runs every `…ViewConstructor.from(node)` helper once. If an enum is
    /// returned, attach it to the *current* SyntaxView.
    private static func createKnownViewConstructor(from node: FunctionCallExprSyntax,
                                                   arguments: [SyntaxViewArgumentData]) -> ViewConstructor? {
        
        guard let name = node.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text,
              let viewName = SyntaxViewName(rawValue: name) else {
            return nil
        }
        
        switch viewName {
        case .text:
            if let ctor = TextViewConstructor.from(arguments) {
                return .text(ctor)
            }
        case .image:
            if let ctor = ImageViewConstructor.from(arguments) {
                return .image(ctor)
            }
        case .hStack:
            if let ctor = HStackViewConstructor.from(arguments) {
                return .hStack(ctor)
            }
//        case .vStack:
//            if let ctor = VStackViewConstructor.from(node).map(ViewConstructor.vStack) {
//                attachConstructor(ctor)
//            }
//        case .lazyHStack:
//            if let ctor = LazyHStackViewConstructor.from(node).map(ViewConstructor.lazyHStack) {
//                attachConstructor(ctor)
//            }
//        case .lazyVStack:
//            if let ctor = LazyVStackViewConstructor.from(node).map(ViewConstructor.lazyVStack) {
//                attachConstructor(ctor)
//            }
//        case .circle:
//            if let ctor = CircleViewConstructor.from(node).map(ViewConstructor.circle) {
//                attachConstructor(ctor)
//            }
//        case .ellipse:
//            if let ctor = EllipseViewConstructor.from(node).map(ViewConstructor.ellipse) {
//                attachConstructor(ctor)
//            }
//        case .rectangle:
//            if let ctor = RectangleViewConstructor.from(node).map(ViewConstructor.rectangle) {
//                attachConstructor(ctor)
//            }
//        case .roundedRectangle:
//            if let ctor = RoundedRectangleViewConstructor.from(node).map(ViewConstructor.roundedRectangle) {
//                attachConstructor(ctor)
//            }
//        case .scrollView:
//            if let ctor = ScrollViewViewConstructor.from(node).map(ViewConstructor.scrollView) {
//                attachConstructor(ctor)
//            }
//        case .zStack:
//            if let ctor = ZStackViewConstructor.from(node).map(ViewConstructor.zStack) {
//                attachConstructor(ctor)
//            }
//        case .textField:
//            if let ctor = TextFieldViewConstructor.from(node).map(ViewConstructor.textField) {
//                attachConstructor(ctor)
//            }
//        case .angularGradient:
//            if let ctor = AngularGradientViewConstructor.from(node).map(ViewConstructor.angularGradient) {
//                attachConstructor(ctor)
//            }
//        case .linearGradient:
//            if let ctor = LinearGradientViewConstructor.from(node).map(ViewConstructor.linearGradient) {
//                attachConstructor(ctor)
//            }
//        case .radialGradient:
//            if let ctor = RadialGradientViewConstructor.from(node).map(ViewConstructor.radialGradient) {
//                attachConstructor(ctor)
//            }
        default:
            break
        }
        
        
//        if let ctor = TextViewConstructor.from(node).map(ViewConstructor.text)
//            ?? ImageViewConstructor.from(node).map(ViewConstructor.image)
//            ?? HStackViewConstructor.from(node).map(ViewConstructor.hStack)
//            ?? VStackViewConstructor.from(node).map(ViewConstructor.vStack)
//            ?? LazyHStackViewConstructor.from(node).map(ViewConstructor.lazyHStack)
//            ?? LazyVStackViewConstructor.from(node).map(ViewConstructor.lazyVStack)
//            ?? CircleViewConstructor.from(node).map(ViewConstructor.circle)
//            ?? EllipseViewConstructor.from(node).map(ViewConstructor.ellipse)
//            ?? RectangleViewConstructor.from(node).map(ViewConstructor.rectangle)
//            ?? RoundedRectangleViewConstructor.from(node).map(ViewConstructor.roundedRectangle)
//            ?? ScrollViewViewConstructor.from(node).map(ViewConstructor.scrollView)
//            ?? ZStackViewConstructor.from(node).map(ViewConstructor.zStack)
//            ?? TextFieldViewConstructor.from(node).map(ViewConstructor.textField)
//            ?? AngularGradientViewConstructor.from(node).map(ViewConstructor.angularGradient)
//            ?? LinearGradientViewConstructor.from(node).map(ViewConstructor.linearGradient)
//            ?? RadialGradientViewConstructor.from(node).map(ViewConstructor.radialGradient)
//        {
//            attachConstructor(ctor)
//        }
        
        return nil
    }
    
    // Visit function call expressions (which represent view initializations and modifiers)
    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        log("Visiting function call: \(node.description)")
        log("Current stack depth: \(viewStack.count), current index: \(String(describing: currentNodeIndex))")
        
        if let identifierExpr = node.calledExpression.as(DeclReferenceExprSyntax.self) {
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
                
            case .value:
                // No view here, just continue
                return .skipChildren
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
    func parseArguments(from node: FunctionCallExprSyntax) -> ViewConstructorType {
        // Default handling for other modifiers
        let arguments = node.arguments.compactMap { (argument) -> SyntaxViewArgumentData? in
            self.parseArgument(argument)
        }
        
        dbg("parseArguments → for \(node.calledExpression.trimmedDescription)  |  \(arguments.count) arg(s): \(arguments)")
        
        guard let knownViewConstructor = SwiftUIViewVisitor
            .createKnownViewConstructor(from: node,
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
    
    /// Handles conditional logic for determining a type of syntax argument.
    func parseArgumentType(from expression: SwiftSyntax.ExprSyntax) -> SyntaxViewModifierArgumentType? {
        // Handles compelx types, like PortValueDescription
        if let funcExpr = expression.as(FunctionCallExprSyntax.self) {
            // Recursively create argument data
            let complexTypeArgs = funcExpr.arguments
                .compactMap { expr in
                    self.parseArgument(expr)
                }
            
            let complexType = SyntaxViewModifierComplexType(
                typeName: funcExpr.calledExpression.trimmedDescription,
                arguments: complexTypeArgs)
            
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
    
    // MARK: - Modifier Handling

    
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
