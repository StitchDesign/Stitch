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
                        modifiers: [SyntaxViewModifier] = [],
                        isStreaming: Bool) -> SyntaxView? {
        let args: ViewConstructorType
        
        do {
            args = try Self.parseArguments(from: node,
                                           isStreaming: isStreaming)
        } catch let error as SwiftUISyntaxError {
            self.caughtErrors.append(error)
            args = .other([])
        } catch {
            fatalErrorIfDebug()
            args = .other([])
        }
        
        // Check for views with view modifier data
        if let memberExpr = node.calledExpression.as(MemberAccessExprSyntax.self) {
            var modifiers = modifiers
            let viewModifierName = memberExpr.declName.baseName.text
            
            if let modifierName = SyntaxViewModifierName(rawValue: viewModifierName) {
                // log("visitViewModifierData: no modifier for \(viewModifierName)")
                let modifier = SyntaxViewModifier(
                    name: modifierName,
                    arguments: args
                )
                modifiers.append(modifier)
            }
            
            guard let fnBase = memberExpr.base?.as(FunctionCallExprSyntax.self) else {
                // Get view builder data
                let declRefExprSyntax = memberExpr.base?.as(MemberAccessExprSyntax.self)?.base?.as(DeclReferenceExprSyntax.self) ?? memberExpr.declName
                
                guard let viewData = self.createViewData(from: declRefExprSyntax,
                                                         args: args,
                                                         modifiers: modifiers) else {
                    return nil
                }
                
                return viewData
            }
            
            return self.visitLayerData(node: fnBase,
                                       modifiers: modifiers,
                                       isStreaming: isStreaming)
        }
        
        // View data
        else if let declRefExprSyntax = node.calledExpression.as(DeclReferenceExprSyntax.self) {
            guard var viewNode = self.createViewData(from: declRefExprSyntax,
                                                     args: args,
                                                     modifiers: modifiers) else {
                return nil
            }
                    
            // Handle children data
            guard let trailingClosure = node.trailingClosure else {
                return viewNode
            }
            
            let childrenViews = trailingClosure.statements
                .compactMap { $0.item.as(FunctionCallExprSyntax.self) }
                .compactMap { self.visitLayerData(node: $0,
                                                  isStreaming: isStreaming) }
            
            viewNode.children = childrenViews
            
            return viewNode
            
        }
        
        return nil
    }
    
    private func createViewData(from declRefExprSyntax: DeclReferenceExprSyntax,
                                args: ViewConstructorType,
                                modifiers: [SyntaxViewModifier]) -> SyntaxView? {
        // This might be a view initialization like Text("Hello")
        let viewName = declRefExprSyntax.baseName.text
        
        return SyntaxView(
            name: viewName,
            // This is creat
            constructorArguments: args,
            modifiers: modifiers,
            children: [],
            id: UUID()
            //                errors: self.caughtErrors
        )
    }
}
