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
    static func parseArguments(from node: FunctionCallExprSyntax) throws -> ViewConstructorType {
        // Default handling for other modifiers
        var arguments = try node.arguments.map { (argument) -> SyntaxViewArgumentData in
            try Self.parseArgument(argument)
        }
        
        // log("parseArguments → for \(node.calledExpression.trimmedDescription)  |  \(arguments.count) arg(s): \(arguments)")
        
        guard let knownViewConstructor = createKnownViewConstructor(
            from: node,
            arguments: arguments) else {
            
            // Append closure arg if exists
            if let closureBlock = node.trailingClosure {
                arguments.append(.init(label: nil,
                                       value: .closure(closureBlock.getClosureData())))
            }
            
            return .other(arguments)
        }
        
        return .trackedConstructor(knownViewConstructor)
    }
    
    static func parseArgument(_ argument: LabeledExprSyntax) throws -> SyntaxViewArgumentData {
        let label = argument.label?.text
        
        let expression = argument.expression
        
        let value = try Self.parseArgumentType(from: expression)
        
        return .init(label: label,
                     value: value)
    }
    
    static func parseFnArgumentType(_ funcExpr: FunctionCallExprSyntax) throws -> SyntaxViewModifierArgumentType {
        // Recursively create argument data
        let complexTypeArgs = try funcExpr.arguments
            .map { expr in
                try Self.parseArgument(expr)
            }
        
        if let memberAccessExpr = funcExpr.calledExpression.as(MemberAccessExprSyntax.self),
           let viewEventName = funcExpr.getViewEventName() {
            
            var modifierClosures = [String: SyntaxViewModifierClosureData]()
            try funcExpr.reduceModifierClosureData(funcExpr: funcExpr,
                                                   memberAccessExpr: memberAccessExpr,
                                                   modifierClosures: &modifierClosures)
            
            return .viewEvent(.init(eventName: viewEventName,
                                    eventConstructorArgs: complexTypeArgs,
                                    eventModifiers: modifierClosures))
        }
        
        let complexType = SyntaxViewModifierComplexType(
            typeName: funcExpr.calledExpression.trimmedDescription,
            arguments: complexTypeArgs)
        
        return .complex(complexType)
    }
    
    /// Handles conditional logic for determining a type of syntax argument.
    static func parseArgumentType(from expression: SwiftSyntax.ExprSyntax) throws -> SyntaxViewModifierArgumentType {
        // Handles compelx types, like PortValueDescription
        if let funcExpr = expression.as(FunctionCallExprSyntax.self) {
            let complexType = try Self.parseFnArgumentType(funcExpr)
            return complexType
        }
        
        // Recursively handle arguments in tuple case
        else if let tupleExpr = expression.as(TupleExprSyntax.self) {
            let tupleArgs = try tupleExpr.elements.map(self.parseArgument(_:))
            return .tuple(tupleArgs)
        }
        
        // Recursively handle arguments in array case
        else if let arrayExpr = expression.as(ArrayExprSyntax.self) {
            let arrayArgs = try arrayExpr.elements.compactMap {
                try Self.parseArgumentType(from: $0.expression)
            }
            return .array(arrayArgs)
        }
        
        else if let memberAccessExpr = expression.as(MemberAccessExprSyntax.self) {
            return .memberAccess(memberAccessExpr)
        }
        
        else if let dictExpr = expression.as(DictionaryExprSyntax.self) {
            // Break down children
            let dictChildren = dictExpr.content.children(viewMode: .sourceAccurate)
            let recursedChildren = try dictChildren.compactMap { dictElem -> SyntaxViewArgumentData? in
                guard let dictElem = dictElem.as(DictionaryElementSyntax.self) else {
                    throw SwiftUISyntaxError.unsupportedSyntaxArgument(dictElem.trimmedDescription)
                }
                
                // get value data recursively
                let value = try Self.parseArgumentType(from: dictElem.value)
                
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
        
        // Closures
        else if let closureExpr = expression.as(ClosureExprSyntax.self) {
            return .closure(closureExpr.getClosureData())
        }
        
        guard let syntaxKind = SyntaxArgumentKind.fromExpression(expression) else {
            throw SwiftUISyntaxError.unsupportedSyntaxArgumentKind(expression.trimmedDescription)
        }

        let data = SyntaxViewSimpleData(
            value: expression.trimmedDescription,
            syntaxKind: syntaxKind
        )
        return .simple(data)
    }
}
