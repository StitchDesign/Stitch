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
    /// Check if a type name represents a SwiftUI view
    static func isSwiftUIViewType(_ typeName: String) -> Bool {
        let swiftUIViews = [
            "VStack", "HStack", "ZStack", "LazyVStack", "LazyHStack",
            "ScrollView", "List", "NavigationView", "NavigationStack",
            "TabView", "Group", "Section", "Form", "GeometryReader",
            "Text", "Image", "Button", "Rectangle", "Circle", "Ellipse"
        ]
        return swiftUIViews.contains(typeName)
    }
    
    /// Check if a type name represents a SwiftUI event/gesture (not a regular view)
    static func isViewEventType(_ typeName: String) -> Bool {
        let eventTypes = [
            "TapGesture", "LongPressGesture", "PanGesture", "DragGesture",
            "MagnificationGesture", "RotationGesture", "ExclusiveGesture",
            "SimultaneousGesture", "SequenceGesture"
        ]
        return eventTypes.contains(typeName)
    }
    
    /// Parse child views from a closure expression
    static func parseViewsFromClosure(_ closure: ClosureExprSyntax) -> [SyntaxView] {
        let visitor = SwiftUIViewVisitor(willParseView: true)
        visitor.walk(closure)
        return visitor.viewStack
    }
    
    /// Parse a single view expression using the existing SwiftUIViewVisitor
    static func parseViewFromExpression(_ funcExpr: FunctionCallExprSyntax) -> SyntaxView? {
        let visitor = SwiftUIViewVisitor(willParseView: true)
        visitor.walk(funcExpr)
        return visitor.viewStack.first
    }
    
    // Parse arguments from function call
    static func parseArguments(from node: FunctionCallExprSyntax,
                               isStreaming: Bool) throws -> ViewConstructorType {
        // Default handling for other modifiers
        var arguments = try node.arguments.map { (argument) -> SyntaxViewArgumentData in
            try Self.parseArgument(argument)
        }
        
        // log("parseArguments → for \(node.calledExpression.trimmedDescription)  |  \(arguments.count) arg(s): \(arguments)")
        
        guard let knownViewConstructor = createKnownViewConstructor(
            from: node,
            arguments: arguments,
            isStreaming: isStreaming) else {
        
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
        
        // Check if this is an actual event/gesture (not a regular view)
        if let memberAccessExpr = funcExpr.calledExpression.as(MemberAccessExprSyntax.self),
           let viewEventName = funcExpr.getViewEventName(),
           isViewEventType(viewEventName) {
            
            var modifierClosures = [String: SyntaxViewModifierClosureData]()
            try funcExpr.reduceModifierClosureData(funcExpr: funcExpr,
                                                   memberAccessExpr: memberAccessExpr,
                                                   modifierClosures: &modifierClosures)
            
            return .viewEvent(.init(eventName: viewEventName,
                                    eventConstructorArgs: complexTypeArgs,
                                    eventModifiers: modifierClosures))
        }
        
        // Check if this is a regular SwiftUI view with modifiers
        if let memberAccessExpr = funcExpr.calledExpression.as(MemberAccessExprSyntax.self),
           let baseViewName = funcExpr.getViewEventName(),
           isSwiftUIViewType(baseViewName) {
            
            // Use existing SwiftUIViewVisitor to parse the entire expression properly
            if let syntaxView = parseViewFromExpression(funcExpr) {
                return .view(syntaxView)
            }
        }
        
        // Check if this is a SwiftUI view with a trailing closure (like VStack, HStack, etc.)
        let typeName = funcExpr.calledExpression.trimmedDescription
        if isSwiftUIViewType(typeName), let trailingClosure = funcExpr.trailingClosure {
            // This is a SwiftUI view with children - parse it as a proper view hierarchy
            let childViews = parseViewsFromClosure(trailingClosure)
            let syntaxView = SyntaxView(
                name: typeName,
                constructorArguments: complexTypeArgs.isEmpty ? nil : .other(complexTypeArgs),
                modifiers: [],
                children: childViews,
                id: UUID()
            )
            return .view(syntaxView)
        }
        
        let complexType = SyntaxViewModifierComplexType(
            typeName: typeName,
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
