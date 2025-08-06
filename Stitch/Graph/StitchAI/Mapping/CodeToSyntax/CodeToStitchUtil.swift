//
//  CodeToStitchUtil.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/31/25.
//

import SwiftSyntax
import SwiftParser
import SwiftSyntaxBuilder
import SwiftUI

extension SwiftUIViewVisitor {
    // Parse arguments from function call
    func parseArguments(from node: FunctionCallExprSyntax) -> ViewConstructorType {
        // Default handling for other modifiers
        let arguments = node.arguments.compactMap { (argument) -> SyntaxViewArgumentData? in
            self.parseArgument(argument)
        }
        
        // log("parseArguments → for \(node.calledExpression.trimmedDescription)  |  \(arguments.count) arg(s): \(arguments)")
        
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

        let data = SyntaxViewSimpleData(
            value: expression.trimmedDescription,
            syntaxKind: syntaxKind
        )
        return .simple(data)
    }
}
