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
}
