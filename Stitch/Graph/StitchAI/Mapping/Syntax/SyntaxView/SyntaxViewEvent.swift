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
    /// Determines the connections and intermediary patch nodes to be created between an interaction patch node and some state.
    func createConnectedPatchData(interactionPatchNodeId: String,
                                  createdPatchesAtThisNode: inout [Patch: CurrentAIGraphData
        .PatchNode],
                                  patchConnections: inout [CurrentAIGraphData.PatchConnection]) -> AIGraphData_V0.NodeIndexedCoordinate? {        
        switch self.viewEvent {
        case .dragGesture:
            // Packed case: arg == "translation" or "position"
            if self.gestureArg == "translation" || self.gestureArg == "position" {
                return AIGraphData_V0.NodeIndexedCoordinate(
                    node_id: interactionPatchNodeId,
                    port_index: 0)
            }
            
            // Unpacked case: need to see the suffix value (i.e. x or y)
            guard let suffixValue = self.gestureArg?.split(separator: ".")[safe: 1] else {
                return nil
            }
            
            if suffixValue == "x" || suffixValue == "width" {
                return Self._positionUnpackCase(outputPortIndex: 0,
                                                interactionPatchNodeId: interactionPatchNodeId,
                                                createdPatchesAtThisNode: &createdPatchesAtThisNode,
                                                patchConnections: &patchConnections)
            } else if suffixValue == "y" || suffixValue == "height" {
                return Self._positionUnpackCase(outputPortIndex: 1,
                                                interactionPatchNodeId: interactionPatchNodeId,
                                                createdPatchesAtThisNode: &createdPatchesAtThisNode,
                                                patchConnections: &patchConnections)
            }
            
            return nil
            
        case .tapGesture:
            // Assume 0 until we handle cases with position
            return AIGraphData_V0.NodeIndexedCoordinate(
                node_id: interactionPatchNodeId,
                port_index: 0)
        }
    }
    
    private static func _positionUnpackCase(outputPortIndex: Int,
                                            interactionPatchNodeId: String,
                                            createdPatchesAtThisNode: inout [Patch: CurrentAIGraphData
                                                .PatchNode],
                                            patchConnections: inout [CurrentAIGraphData.PatchConnection]) -> AIGraphData_V0.NodeIndexedCoordinate {
        // Create unpack position node if not already made
        let unpackPositionNode = createdPatchesAtThisNode.get(.positionUnpack) ?? .init(
            node_id: UUID().uuidString,
            node_name: .init(value: .patch(.positionUnpack)))
        createdPatchesAtThisNode.updateValue(unpackPositionNode, forKey: .positionUnpack)
        
        // Connect drag node to unpack node
        patchConnections.append(.init(
            src_port: .init(node_id: interactionPatchNodeId,
                            port_index: 0),
            dest_port: .init(node_id: unpackPositionNode.node_id,
                             port_index: 0)))
        
        // Return output port index of unpack node
        return .init(node_id: unpackPositionNode.node_id,
                     port_index: outputPortIndex)
    }
}

extension SyntaxViewModifierViewEvent {
    func deriveViewEventData() throws -> [AIGraphData_V0.LayerDataViewEvent] {
        // Check for onChange handlers
        guard let viewName = SyntaxViewEvent(rawValue: self.eventName),
              let onChangeHandler = self.eventModifiers.get("onChanged") else {
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
                        guard let paramVarName = onChangeHandler.paramVars.first,
                              let memberAccess = arg.value.memberAccess ?? arg.value.complexValue?.arguments.first?.value.memberAccess else {
                            return nil
                        }
                        
                        var propertyString = memberAccess.trimmedDescription
                        let prefixStr = "\(paramVarName)."
                        
                        if propertyString.hasPrefix(prefixStr) {
                            propertyString = String(propertyString.dropFirst(prefixStr.count))
                        }
                        
                        return propertyString
                    }.first
                    
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
