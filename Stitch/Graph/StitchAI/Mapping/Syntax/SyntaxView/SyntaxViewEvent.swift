//
//  SyntaxViewEvent.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 8/26/25.
//

import SwiftUI
import SwiftSyntax
import SwiftParser
import SwiftSyntaxBuilder

enum SyntaxViewEvent: String, Sendable, Encodable {
    case dragGesture = "DragGesture"
    case tapGesture = "TapGesture"
}

struct SyntaxViewModifierViewEvent: Sendable {
    let eventName: String
    
    // args inside constructor
    let eventConstructorArgs: [SyntaxViewArgumentData]
    
    // member access callbacks with possible closure data
    let eventModifiers: [String: SyntaxViewModifierClosureData]
}

extension SyntaxViewEvent {
    var patch: Patch {
        switch self {
        case .dragGesture:
            return .dragInteraction
        case .tapGesture:
            return .pressInteraction
        }
    }
}

extension AIGraphData_V0.LayerDataViewEvent {
    /// Given some view event name and property used for state mutation, determine which output port index is used in Stitch.
    var patchNodeOutputPort: Int? {
        let property = self.gestureArg
        
        switch self.viewEvent {
        case .dragGesture:
            if property?.contains("translation") ?? false {
                return 0
            }
            
        case .tapGesture:
            // Assume 0 until we handle cases with position
            return 0
        }
        
        return nil
    }
}

extension SyntaxViewModifierViewEvent {
    func deriveViewEventData() throws -> [AIGraphData_V0.LayerDataViewEvent] {
        // Check for onChange handlers
        guard let viewName = SyntaxViewEvent(rawValue: self.eventName),
              let onChangeHandler = self.eventModifiers.get("onChanged"),
              let gestureParamName = onChangeHandler.paramVars.first else {
            return []
        }
        
        // Parse script for determining what populates state
        let parsedData = SwiftUIViewVisitor.parseSwiftUICode(onChangeHandler.script,
                                                             willParseView: false)
        
        return try parsedData.bindingDeclarations.compactMap { keyValue -> AIGraphData_V0.LayerDataViewEvent? in
            let (refName, assignmentValue) = keyValue
            
            switch assignmentValue {
            case .stateMutation(let stateMutationAssignment):
                switch stateMutationAssignment {
                case .arraySyntax(let arraySyntax):
                    // Find what we're parsing
                    guard let funcExpr = arraySyntax.elements.first?.expression.as(FunctionCallExprSyntax.self) else {
                        return nil
                    }
                    
                    let args = try SwiftUIViewVisitor.parseArguments(from: funcExpr)
                    
                    guard let defaultArgs = args.defaultArgs else {
                        return nil
                    }
                    
                    // Find the property that's read from the gesture param
                    let gestureArg = defaultArgs.compactMap { arg -> String? in
                        guard let memberSyntax = arg.value.memberAccess else {
                            return nil
                        }
                        
                        var propertyString = memberSyntax.trimmedDescription
                        let prefixStr = "\(gestureParamName)."
                        
                        if propertyString.hasPrefix(prefixStr) {
                            propertyString = String(propertyString.dropFirst(prefixStr.count))
                        }
                        
                        return propertyString
                    }.first
                    
                    guard let gestureArg = gestureArg else {
                        return nil
                    }
                    
                    return .init(viewEvent: viewName,
                                 gestureArg: gestureArg,
                                 mutatedStateVar: refName)
                default:
                    return nil
                }
                
            default:
                return nil
            }
        }
    }
}
