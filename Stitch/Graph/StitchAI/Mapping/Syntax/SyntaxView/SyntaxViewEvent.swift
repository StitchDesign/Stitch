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
//    let unpackPositionNodeId = UUID()
    
    // Assigned layer id
    let layerId: UUID
    
    let type: SyntaxViewEventType
    
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

//struct LayerDataViewEvent {
//    let viewEvent: SyntaxViewEvent
//    
//    // If relevant, the argument data that's read from the view event's closure.
//    // i.e. `translation.width`
//    let gestureArg: String?
//    
//    // Tracks which state variable is mutated
//    let mutatedStateVar: String
//}

struct LayerDataViewEventsResult {
    let viewEvent: SyntaxViewEvent
    let actionsResult: SwiftSyntaxPatchActionsResult
}

//extension LayerDataViewEventsResult {
//    init() {
//        self.events = []
//        self.caughtErrors = []
//    }
//}

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
    /// Determines the connections and intermediary patch nodes to be created between an interaction patch node and some state.
    @MainActor
    func createConnectedPatchData(gestureArg: MemberAccessExprSyntax?,
                                  varName: String,
                                  nodesDict: [UUID: NodeEntity]) -> [PatchSyntaxResultType] {
        let assignedLayerPortValue = PortValue
            .assignedLayer(.init(self.layerId))
        
        switch self.type {
        case .dragGesture:
            guard let gestureArg = gestureArg else {
                fatalErrorIfDebug()
                return []
            }
            
            
            // Packed case: arg == "translation" or "position"
            if gestureArg.trimmedDescription == "translation" || gestureArg.trimmedDescription == "position" {
                var dragNode = Patch.dragInteraction
                    .defaultNodeEntity(nodeId: deterministicUUID(from: varName),
                                       groupNodeId: nil,
                                       nodesDict: nodesDict)
                dragNode.inputs[0] = .values([assignedLayerPortValue])

                // position = 0th port, translation = 2nd port
                let outputPortIndex = gestureArg.trimmedDescription == "position" ? 0 : 2
                
                return [
                    .node(dragNode),
                    .portData(
                        .upstreamConnection(NodeIOCoordinate(portId: outputPortIndex,
                                                             nodeId: self.interactionPatchNodeId))
                    )
                ]
            }
            
            // Unpacked case: need to see the suffix value (i.e. x or y)
//            guard let split = self.gestureArg?.split(separator: "."),
//                  let prefixValue = split[safe: 0],
//                  let suffixValue = split[safe: 1] else {
//                return nil
//            }
            
            guard let prefixValue = gestureArg.base?.trimmedDescription else {
                return []
            }
            
            var dragNode = Patch.dragInteraction
                .defaultNodeEntity(nodeId: self.interactionPatchNodeId,
                                   groupNodeId: nil,
                                   nodesDict: nodesDict)
            
            dragNode.inputs[0] = .values([assignedLayerPortValue])
            
            let suffixValue = gestureArg.declName.trimmedDescription
            let outputPortIndex = prefixValue == "position" ? 0 : 2
            
            // Most downstream reference used for node ID
            let unpackNodeId = deterministicUUID(from: varName)
            
            if suffixValue == "x" || suffixValue == "width" {
                let unpackPositionNode = Patch.unpack
                    .defaultNodeEntity(nodeId: unpackNodeId,
                                       groupNodeId: nil,
                                       nodesDict: nodesDict)
                
                let connection = PortEdgeData(
                    from: .init(portId: outputPortIndex,
                                nodeId: self.interactionPatchNodeId),
                    to: .init(portId: 0, nodeId: unpackPositionNode.id))
                
                return [
                    .node(dragNode),
                    .node(unpackPositionNode),
                    .connection(connection),
                    .portData(
                        .upstreamConnection(.init(portId: 0,
                                                  nodeId: unpackPositionNode.id))
                    )
                ]
            } else if suffixValue == "y" || suffixValue == "height" {
                let unpackPositionNode = Patch.unpack
                    .defaultNodeEntity(nodeId: unpackNodeId,
                                       groupNodeId: nil,
                                       nodesDict: nodesDict)
                
                let connection = PortEdgeData(
                    from: .init(portId: outputPortIndex,
                                nodeId: interactionPatchNodeId),
                    to: .init(portId: 0, nodeId: unpackPositionNode.id))
                
                return [
                    .node(dragNode),
                    .node(unpackPositionNode),
                    .connection(connection),
                    .portData(
                        .upstreamConnection(.init(portId: 1,
                                                  nodeId: unpackPositionNode.id))
                    )
                ]
            }
            
            return []
            
        case .tapGesture:
            let pressNodeId = deterministicUUID(from: varName)
            var pressNode = Patch.pressInteraction
                .defaultNodeEntity(nodeId: pressNodeId,
                                   groupNodeId: nil,
                                   nodesDict: nodesDict)
            
            pressNode.inputs[0] = .values([assignedLayerPortValue])
            
            // Assume 0 until we handle cases with position
            return [
                .node(pressNode),
                .portData(
                    .upstreamConnection(.init(portId: 0,
                                              nodeId: pressNodeId))
                )
            ]
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
    @MainActor
    func deriveViewEventData(layerId: UUID) throws -> SwiftPatchViewEvent? {
        // Check for onChange handlers
        guard let viewName = SyntaxViewEventType(rawValue: self.eventName),
              let onChangeHandler = self.eventModifiers.get("onChanged") else {
            return nil
        }
        
        // Parse script for determining what populates state
        let parsedData = SwiftUIViewVisitor.parseSwiftUICode(onChangeHandler.script,
                                                             willParseView: false)
        
        var actionsResult: [(String, SwiftPatchCodeType)] = []
        
        let param = onChangeHandler.paramVars.first
        let eventData = SyntaxViewEvent(layerId: layerId,
                                        type: viewName,
                                        gestureArg: param)
        
        actionsResult += try parsedData.bindingDeclarations
            .getSwiftPatchCodeTypes()
        
        return .init(viewEvent: eventData,
                     codeStatements: actionsResult)
//        let events = try parsedData.bindingDeclarations.compactMap { keyValue -> LayerDataViewEvent? in
//            let (refName, assignmentValue) = keyValue
            
//            switch assignmentValue {
//            case .stateMutation(let stateMutationAssignment):
//                switch stateMutationAssignment {
//                case .arraySyntax(let arraySyntax):
//                    // Find what we're parsing
//                    guard let funcExpr = arraySyntax.elements.first?.expression.as(FunctionCallExprSyntax.self) else {
//                        return nil
//                    }
//                    
//                    let args: ViewConstructorType
//                    do {
//                        args = try SwiftUIViewVisitor.parseArguments(from: funcExpr)
//                    } catch let error as SwiftUISyntaxError {
//                        caughtErrors.append(error)
//                        return nil
//                    } catch {
//                        throw error
//                    }
//                    
//                    var gestureArg: String?
//                    
//                    guard let defaultArgs = args.defaultArgs else {
//                        return nil
//                    }
//                    
//                    // A little hacky--if PortValueDescription of position type, return a packed variable
//                    if (defaultArgs[safe: 1]?.value.simpleValue?.contains("position") ?? false) {
//                        // TODO: see if position or translation
//                        gestureArg = "position"
//                    }
//                    
//                    else {
//                        // Find the property that's read from the gesture param
//                        gestureArg = defaultArgs.compactMap { arg -> String? in
//                            guard let paramVarName = onChangeHandler.paramVars.first,
//                                  let memberAccess = arg.value.firstMemberAccess else {
//                                return nil
//                            }
//                            
//                            var propertyString = memberAccess.trimmedDescription
//                            let prefixStr = "\(paramVarName)."
//                            
//                            if propertyString.hasPrefix(prefixStr) {
//                                propertyString = String(propertyString.dropFirst(prefixStr.count))
//                            }
//                            
//                            return propertyString
//                        }.first
//                    }
//                    
//                    return .init(viewEvent: viewName,
//                                 gestureArg: gestureArg,
//                                 mutatedStateVar: refName)
//                default:
//                    return nil
//                }
//                
//            default:
//                return nil
//            }
//        }
        
//        return .init(events: events,
//                     caughtErrors: caughtErrors)
    }
}
