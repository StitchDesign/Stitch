//
//  CodeToStitchLayerData.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/31/25.
//

import SwiftSyntax
import SwiftParser
import SwiftSyntaxBuilder
import SwiftUI

extension SwiftUIViewVisitor {
//    // Recursively calls for `MemberAccessExprSyntax` until no more exist.
//    func visitViewModifierData(node: MemberAccessExprSyntax) -> [SyntaxViewModifier] {
//        let viewModifierName = node.declName.baseName.text
//        
//        guard let fnBase = node.base?.as(FunctionCallExprSyntax.self) else {
//            fatalErrorIfDebug()
//            return []
//        }
//        
//        let args = self.parseArguments(from: fnBase)
//        
//        guard let modifierName = SyntaxViewModifierName(rawValue: viewModifierName) else {
//            log("visitViewModifierData: no modifier for \(viewModifierName)")
//            return []
//        }
//        
//        let modifier = SyntaxViewModifier(
//            name: modifierName,
//            arguments: args
//        )
//        
//        guard let nestedMemberAccessExprSyntax = fnBase.calledExpression.as(MemberAccessExprSyntax.self) else {
//            return [modifier]
//        }
//        
//        return [modifier] + self.visitViewModifierData(node: nestedMemberAccessExprSyntax)
//    }
    
    // Recursively calls for `MemberAccessExprSyntax` until no more exist.
//    func visitViewModifierData(node: MemberAccessExprSyntax) -> SyntaxViewModifier? {
//        let viewModifierName = node.declName.baseName.text
//        
//        guard let fnBase = node.base?.as(FunctionCallExprSyntax.self) else {
//            fatalErrorIfDebug()
//            return nil
//        }
//        
//        let args = self.parseArguments(from: fnBase)
//        
//        guard let modifierName = SyntaxViewModifierName(rawValue: viewModifierName) else {
//            log("visitViewModifierData: no modifier for \(viewModifierName)")
//            return nil
//        }
//        
//        let modifier = SyntaxViewModifier(
//            name: modifierName,
//            arguments: args
//        )
//        
//        return modifier
//    }
    
    func visitLayerData(node: FunctionCallExprSyntax,
                        modifiers: [SyntaxViewModifier] = []) -> SyntaxView? {
        let args = self.parseArguments(from: node)
        
        // Check for views with view modifier data
        if let memberExpr = node.calledExpression.as(MemberAccessExprSyntax.self) {
            var modifiers = modifiers
            let viewModifierName = memberExpr.declName.baseName.text
            
            if let modifierName = SyntaxViewModifierName(rawValue: viewModifierName) {
                log("visitViewModifierData: no modifier for \(viewModifierName)")
                let modifier = SyntaxViewModifier(
                    name: modifierName,
                    arguments: args
                )
                modifiers.append(modifier)
            }
            
            guard let fnBase = memberExpr.base?.as(FunctionCallExprSyntax.self) else {
                fatalErrorIfDebug()
                return nil
            }
            
            return self.visitLayerData(node: fnBase,
                                       modifiers: modifiers)
        }
        
        // View data
        else if let declRefExprSyntax = node.calledExpression.as(DeclReferenceExprSyntax.self) {
            // This might be a view initialization like Text("Hello")
            let viewName = declRefExprSyntax.baseName.text
            
            guard let nameType = SyntaxNameType.from(viewName) else {
                //                fatalErrorIfDebug("No view discovered for: \(viewName)")
                //            log("No concept discovered for: \(viewName)")
                
                // Tracks for later silent failures
                self.caughtErrors.append(.unsupportedSyntaxViewName(viewName))
                
                return nil
            }
            
            switch nameType {
            case .view(let syntaxViewName):
                // Create a new ViewNode for this view
                var viewNode = SyntaxView(
                    name: syntaxViewName,
                    // This is creat
                    constructorArguments: args,
                    modifiers: modifiers,
                    children: [],
                    id: UUID()
                    //                errors: self.caughtErrors
                )
                
                // Handle children data
                guard let trailingClosure = node.trailingClosure else {
                    return viewNode
                }
                
                let childrenViews = trailingClosure.statements
                    .compactMap { $0.item.as(FunctionCallExprSyntax.self) }
                    .compactMap { self.visitLayerData(node: $0) }
                
                viewNode.children = childrenViews
                
                return viewNode
                
            case .value:
                // No view here, just continue
                return nil
            }
        }
        
        fatalErrorIfDebug()
        return nil
    }

    
    // Helper to get current ViewNode
//    var currentViewNode: SyntaxView? {
//        guard let index = currentNodeIndex, index < viewStack.count else { return nil }
//        return viewStack[index]
//    }
    
    /// Returns the modifier name if `node` is a *view modifier* call
    /// (i.e. a `FunctionCallExprSyntax` whose `calledExpression` is a
    /// `MemberAccessExprSyntax` **with a non‑nil base**).
    /// Helper/static calls that appear only as *arguments* – such as
    /// `.degrees(90)` or `.black` – have `base == nil`, so they are
    /// filtered out.
    func modifierNameIfViewModifier(_ node: FunctionCallExprSyntax) -> String? {
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
//    private func bubbleChangeUp(from index: Int) {
//        var childIndex = index
//        while childIndex > 0 {
//            let parentIndex = childIndex - 1
//            var parent = viewStack[parentIndex]
//            let child = viewStack[childIndex]
//            
//            if let match = parent.children.firstIndex(where: { $0.id == child.id }) {
//                parent.children[match] = child
//                viewStack[parentIndex] = parent
//            } else {
//                // Shouldn’t happen, but avoid infinite loop
//                break
//            }
//            childIndex = parentIndex
//        }
////        if !viewStack.isEmpty {
////            rootViewNode = viewStack[0]
////        }
//    }

    // Helper to update currentViewNode properly
//    private func updateCurrentViewNode(_ newNode: SyntaxView) {
//        guard let index = currentNodeIndex, index < viewStack.count else { return }
//        viewStack[index] = newNode
//        bubbleChangeUp(from: index)
//    }
//    
    // Helper to add a modifier to the current view node
    private func addModifier(_ modifier: SyntaxViewModifier) {
        let modName = modifier.name.rawValue
//        log("addModifier → \(modName) to current index \(String(describing: currentNodeIndex))")
//        guard let index = currentNodeIndex, index < viewStack.count else {
////            log("⚠️ Cannot add modifier: no current view node")
//            return
//        }
//        
//        var node = viewStack[index]
//        log("Adding modifier \(modName) to \(node.name.rawValue)")
//        self.currentView?.modifiers.append(modifier)
//        viewStack[index] = node
        // Bubble the change up to keep all ancestors current
//        bubbleChangeUp(from: index)
//        log("✅ After adding modifier - modifiers count: \(node.modifiers.count)")
//        log("addModifier → completed. Node \(node.name.rawValue) now has \(node.modifiers.count) modifier(s).")
    }

    /// Handles standard modifiers with generic argument parsing
    func handleStandardModifier(node: FunctionCallExprSyntax,
                                modifierName: SyntaxViewModifierName) {
        let modifierArguments = self.parseArguments(from: node)
        
        let modifier = SyntaxViewModifier(
            name: modifierName,
            arguments: modifierArguments
        )
        addModifier(modifier)
    }
}
