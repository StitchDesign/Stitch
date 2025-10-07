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

struct SyntaxViewEvent: Hashable {
    // Creates constant IDs to prevent redundant creation of nodes
//    let pressPatchNodeId = UUID()
    let interactionPatchNodeId = UUID()
    let unpackPositionNodeId = UUID()
    
    // Assigned layer id
    let layerId: UUID
    
    var type: SyntaxViewEventType
    
    // Expressions should only be read from patch node fn params
    let gestureArg: String?
}

enum SyntaxViewEventType: String, Sendable, Encodable {
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

struct LayerDataViewEventsResult {
    let viewEvent: SyntaxViewEvent
    let actionsResult: SwiftSyntaxPatchActionsResult
}

extension SyntaxViewEventType {
    var patch: Patch {
        switch self {
        case .dragGesture:
            return .dragInteraction
        case .tapGesture:
            return .pressInteraction
        }
    }
}

extension Patch {
    var syntaxViewEvent: SyntaxViewEventType? {
        switch self {
        case .dragInteraction:
            return .dragGesture
        case .pressInteraction:
            return .tapGesture
        default: return nil
        }
    }
}

extension SyntaxViewEvent {
    private func processDragEvent(varName: String?,
                                  unpackOutputPortId: Int,
                                  dragNodeResult: PatchSyntaxNodeResult,
                                  assignedLayerValuesResult: PatchSyntaxPortValuesResult) -> [PatchSyntaxResultType] {
        // Determine event for receiver of gesture data
        var gestureReceiverEvent: PatchSyntaxResultType?
        
        // MARK: default to 0, which is the position output, since translate doesn't lead to consistently positive outcomes
        let outputPortIndex = 0 //prefixValue == "position" ? 0 : 2
        
        if let varName = varName {
            let unpackOutput = NodeIOCoordinate(portId: unpackOutputPortId,
                                                nodeId: self.unpackPositionNodeId)
            
            // Most downstream reference used for node ID
            gestureReceiverEvent = .stateWrite(varName, .upstreamConnection(unpackOutput))
        }
        
        let connection = PortEdgeData(
            from: .init(portId: outputPortIndex,
                        nodeId: self.interactionPatchNodeId),
            to: .init(portId: 0, nodeId: self.unpackPositionNodeId))
        
        let unpackPositionNodeResult = PatchSyntaxNodeResult(
            id: self.unpackPositionNodeId,
            kind: .patch(.unpack)
        )
        
        var results: [PatchSyntaxResultType] = [
            .node(dragNodeResult),
            .node(unpackPositionNodeResult),
            .portValues(assignedLayerValuesResult),
            .connection(connection)
        ]
        
        if let gestureReceiverEvent = gestureReceiverEvent {
            results.append(gestureReceiverEvent)
        }
        
        return results
    }
    
    /// Determines the connections and intermediary patch nodes to be created between an interaction patch node and some state.
    func createConnectedPatchData(gestureArg: ExprSyntaxProtocol?,
                                  varName: String?) -> [PatchSyntaxResultType] {
        let assignedLayerPortValue = PortValue
            .assignedLayer(.init(self.layerId))
        let assignedLayerValuesResult = PatchSyntaxPortValuesResult(
            inputCoordinate: .init(portId: 0,
                                   nodeId: self.interactionPatchNodeId),
            values: [assignedLayerPortValue])
        
        switch self.type {
        case .dragGesture:
            if let gestureArg = gestureArg {
                let dragNodeResult = PatchSyntaxNodeResult(id: self.interactionPatchNodeId,
                                                           kind: .patch(.dragInteraction))
                
                // Packed case: arg == "translation" or "position"
                if let declrGestureArg = gestureArg.as(DeclReferenceExprSyntax.self),
                   declrGestureArg.trimmedDescription == "translation" || declrGestureArg.trimmedDescription == "position" {
                    // position = 0th port, translation = 2nd port
                    let outputPortIndex = gestureArg.trimmedDescription == "position" ? 0 : 2
                    
                    let patchOutput = NodeIOCoordinate(portId: outputPortIndex,
                                                       nodeId: self.interactionPatchNodeId)
                    
                    var results: [PatchSyntaxResultType] = [
                        .node(dragNodeResult),
                        .portValues(assignedLayerValuesResult)
                    ]
                    
                    if let varName = varName {
                        let gestureReceiverEvent = PatchSyntaxResultType.stateWrite(varName, .upstreamConnection(patchOutput))
                        results.append(gestureReceiverEvent)
                    }
                    
                    return results
                }
                
                guard let memberGestureArg = gestureArg.as(MemberAccessExprSyntax.self) else {
                    //                  let prefixValue = memberGestureArg.base?.trimmedDescription else {
                    return []
                }
                
                let suffixValue = memberGestureArg.declName.trimmedDescription
                
                if suffixValue == "x" || suffixValue == "width" {
                    return self
                        .processDragEvent(varName: varName,
                                          unpackOutputPortId: 0,
                                          dragNodeResult: dragNodeResult,
                                          assignedLayerValuesResult: assignedLayerValuesResult)
                }
                
                else if suffixValue == "y" || suffixValue == "height" {
                    return self
                        .processDragEvent(varName: varName,
                                          unpackOutputPortId: 1,
                                          dragNodeResult: dragNodeResult,
                                          assignedLayerValuesResult: assignedLayerValuesResult)
                }
            }
            
            return []
            
        case .tapGesture:
            // Determine event for receiver of gesture data
            var gestureReceiverEvent: PatchSyntaxResultType?
            
            let pressOutput = NodeIOCoordinate(portId: 0,
                                               nodeId: self.interactionPatchNodeId)
            
            if let varName = varName {
                gestureReceiverEvent = .stateWrite(varName, .upstreamConnection(pressOutput))
            }
            
            // Assume 0 until we handle cases with position
            var results: [PatchSyntaxResultType] = [
                .node(.init(id: self.interactionPatchNodeId, kind: .patch(.pressInteraction))),
                .portValues(assignedLayerValuesResult)
            ]
            
            if let gestureReceiverEvent = gestureReceiverEvent {
                results.append(gestureReceiverEvent)
            }
            
            return results
        }
    }
    
    private static func _positionUnpackCase(outputInteractionPortIndex: Int,
                                            outputUnpackPortIndex: Int,
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
                            port_index: outputInteractionPortIndex),
            dest_port: .init(node_id: unpackPositionNode.node_id,
                             port_index: 0)))
        
        // Return output port index of unpack node
        return .init(node_id: unpackPositionNode.node_id,
                     port_index: outputUnpackPortIndex)
    }
}

extension SyntaxViewModifierViewEvent {
    func deriveViewEventData(layerId: UUID,
                             isStreaming: Bool) throws -> SwiftPatchViewEvent? {
        // Check for onChange handlers
        guard let viewName = SyntaxViewEventType(rawValue: self.eventName),
              // MARK: we just want to ignore onEnded, we don't support that yet
                let onChangeHandler = self.eventModifiers.get("onChanged") ?? self.eventModifiers.values.first else {
            return nil
        }
        
        // Parse script for determining what populates state
        let parsedData = SwiftUIViewVisitor.parseSwiftUICode(onChangeHandler.script,
                                                             willParseView: false,
                                                             isStreaming: isStreaming)
        
        var actionsResult: [(String, SwiftPatchCodeType)] = []
        
        let param = onChangeHandler.paramVars.first
        let eventData = SyntaxViewEvent(layerId: layerId,
                                        type: viewName,
                                        gestureArg: param)
        
        actionsResult += try parsedData.bindingDeclarations
            .getSwiftPatchCodeTypes(isStreaming: isStreaming)
        
        return .init(viewEvent: eventData,
                     codeStatements: actionsResult)
    }
}
