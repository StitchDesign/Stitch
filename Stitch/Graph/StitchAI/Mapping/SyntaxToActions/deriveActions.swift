//
//  deriveActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation
import SwiftUI
import SwiftSyntax
import SwiftParser
import SwiftSyntaxBuilder

struct SwiftSyntaxLayerActionsResult {
    var actions: [CurrentAIGraphData.LayerData]
    var caughtErrors: [SwiftUISyntaxError]
}

struct SwiftSyntaxPatchActionsResult {
//    var actions: CurrentAIGraphData.PatchData
    var nodes: [NodeEntity]
    
    var stateVarConnections: [String: [NodeIOCoordinate]]
    
    // Tracks any upstream patches that connect to some state
    // Key = state variable name
    // Value = upstream coordinate
//    var viewStatePatchConnections: [String : AIGraphData_V0.NodeIndexedCoordinate]
    
    var caughtErrors: [SwiftUISyntaxError]
}

extension SwiftSyntaxPatchActionsResult {
    init() {
        self.init(nodes: [],
                  stateVarConnections: .init(),
                  caughtErrors: [])
    }
    
    static func + (lhs: Self, rhs: Self) -> Self {
        var lhs = lhs
        lhs.nodes += rhs.nodes
        lhs.stateVarConnections.merge(rhs.stateVarConnections, uniquingKeysWith: { $1 })
        lhs.caughtErrors += rhs.caughtErrors
        return lhs
    }
    
    static func += (lhs: inout Self, rhs: Self) {
        lhs = lhs + rhs
    }
}

extension AIGraphData_V0.PatchData {
    static func + (lhs: Self, rhs: Self) -> Self {
        var lhs = lhs
        lhs.custom_patch_input_values += rhs.custom_patch_input_values
        lhs.javascript_patches += rhs.javascript_patches
        lhs.native_patch_value_type_settings += rhs.native_patch_value_type_settings
        lhs.native_patches += rhs.native_patches
        lhs.patch_connections += rhs.patch_connections
        return lhs
    }
    
    static func += (lhs: inout Self, rhs: Self) {
        lhs = lhs + rhs
    }
}

struct SwiftSyntaxActionsResult {
    var graphData: CurrentAIGraphData.GraphData
    
    var caughtErrors: [SwiftUISyntaxError]
}

extension SwiftUIViewParserResult {
    @MainActor
    func deriveStitchActions(bindingDeclarations: [(String, SwiftParserInitializerType)],
                             document: StitchDocumentViewModel) async throws -> SwiftSyntaxActionsResult {
        // Extract layer data
        let layerResults = self.viewStack.deriveStitchActions(bindingDeclarations: bindingDeclarations)
        
        let interactionsPatchActionResult = layerResults.actions.getPatchResultsFromViewEvents()
        
        let patchCodeStatements = try SwiftPatchClosureType.swiftPatchLogic(self.bindingDeclarations.getSwiftPatchCodeTypes())

        // Prepend view event data for code from `updateLayerInputs`
        let allPatchCode: [SwiftPatchClosureType] = interactionsPatchActionResult.map { .viewEvent($0) } + [patchCodeStatements]
        
//        let debugPatchStrings = allPatchCode.map { "\($0)" }
//            .joined(separator: "\n")
//        print("PATCH DATA:\n\(debugPatchStrings)")
        
        let patchResult = await allPatchCode.derivePatchNodes(document: document)
        
//        let patchResults = self.bindingDeclarations.deriveStitchActions(existingData: interactionsPatchActionResult)
        
        return .init(graphData: .init(layer_data_list: layerResults.actions,
                                      patchNodes: patchResult.nodes,
                                      viewStatePatchConnections: patchResult.stateVarConnections),
                     caughtErrors: self.caughtErrors + layerResults.caughtErrors)// + patchResults.caughtErrors)
    }
}

extension Array where Element == SyntaxView {
    @MainActor
    func deriveStitchActions(bindingDeclarations: [(String, SwiftParserInitializerType)]) -> SwiftSyntaxLayerActionsResult {
        var result = SwiftSyntaxLayerActionsResult(actions: [],
                                                   caughtErrors: [])
        
        for viewData in self {
            let actions = viewData.deriveStitchActions(bindingDeclarations: bindingDeclarations)
            result.actions += actions?.actions ?? []
            result.caughtErrors += actions?.caughtErrors ?? []
        }
        
        return result
    }
}

extension Array where Element == AIGraphData_V0.LayerData {
    func getPatchResultsFromViewEvents() -> [SwiftPatchViewEvent] {
        self.reduce(into: [SwiftPatchViewEvent]()) { result, layerData in
            if let actionsResult = layerData.view_events {
                result += actionsResult
            }
            
            if let children = layerData.children {
                result += children.getPatchResultsFromViewEvents()
            }
        }
    }
    
    /// Roles:
    /// 1. Determines interaction patch nodes to make based on view events attached to view modifiers.
    /// 2. Returns dictionary of a state var name to a newly created patch node's output coordinate.
//    func createStateVarToInteractionNodeMap(nativePatchNodes: inout [String: CurrentAIGraphData.PatchNode],
//                                            customPatchInputValues: inout [CurrentAIGraphData.CustomPatchInputValue],
//                                            viewStatePatchConnections: inout [String : AIGraphData_V0.NodeIndexedCoordinate],
//                                            patchConnections: inout [CurrentAIGraphData.PatchConnection]) -> [String: CurrentAIGraphData.NodeIndexedCoordinate] {
//        self.reduce(into: [String: CurrentAIGraphData.NodeIndexedCoordinate]()) { result, layerData in
//            var createdPatchesAtThisNode = [Patch: CurrentAIGraphData
//                .PatchNode]()
//            
//            layerData.view_events.forEach { viewEvent in
//                let patch = viewEvent.viewEvent.patch
//                let existingPatchNode = createdPatchesAtThisNode.get(patch)
//                let patchNode = existingPatchNode ?? .init(node_id: UUID().uuidString,
//                                                           node_name: .init(value: .patch(patch)))
//                
//                guard let upstreamStateCoordinate = viewEvent.viewEvent
//                    .createConnectedPatchData(interactionPatchNodeId: patchNode.node_id,
//                                              createdPatchesAtThisNode: &createdPatchesAtThisNode,
//                                              patchConnections: &patchConnections) else {
//                    return
//                }
//                
//                // Update layer assignment for node
//                customPatchInputValues.append(
//                    .init(patch_input_coordinate: .init(node_id: patchNode.node_id,
//                                                        port_index: 0),
//                          value: layerData.node_id,
//                          value_type: .init(value: .interactionId))
//                )
//                
//                // Update view state connections
//                viewStatePatchConnections.updateValue(upstreamStateCoordinate,
//                                                      forKey: viewEvent.mutatedStateVar)
//                
//                // Update (possibly new) patch
//                createdPatchesAtThisNode.updateValue(patchNode, forKey: patch)
//                
//                // Output coordinates to return
//                result.updateValue(upstreamStateCoordinate,
//                                   forKey: viewEvent.mutatedStateVar)
//            }
//            
//            // Add any created patch nodes to the native nodes list
//            createdPatchesAtThisNode.values.forEach { patchNode in
//                nativePatchNodes.updateValue(patchNode,
//                                             forKey: patchNode.node_id)
//            }
//            
//            // Recursively explore children
//            if let childrenDict = layerData.children?
//                .createStateVarToInteractionNodeMap(nativePatchNodes: &nativePatchNodes,
//                                                    customPatchInputValues: &customPatchInputValues,
//                                                    viewStatePatchConnections: &viewStatePatchConnections,
//                                                    patchConnections: &patchConnections) {
//                result.merge(childrenDict, uniquingKeysWith: { $1 })
//            }
//        }
//    }
    
    /// Recursively gathers all view event data
    /// * key = layer id
    /// * value = view event data
    func getAllViewEventsMap() -> [UUID: [SwiftPatchViewEvent]] {
        self.reduce(into: .init()) { result, layerData in
            if let id = UUID(layerData.node_id),
               let viewEvents = layerData.view_events {
                result.updateValue(viewEvents, forKey: id)
            }
            
            if let appendedChildrenResult = layerData.children {
                let childResults = appendedChildrenResult.getAllViewEventsMap()
                result = result.merging(childResults) { $1 }
            }
        }
    }
}

//extension LayerDataViewEvent {
//    func updateInteractionData(layerId: UUID,
//                               nativePatchNodes: inout [String: CurrentAIGraphData.PatchNode],
//                               customPatchInputValues: inout [CurrentAIGraphData.CustomPatchInputValue],
//                               viewStatePatchConnections: inout [String : AIGraphData_V0.NodeIndexedCoordinate],
//                               patchConnections: inout [CurrentAIGraphData.PatchConnection]) {
//            let patch = self.viewEvent.patch
////            let existingPatchNode = createdPatchesAtThisNode.get(patch)
//            let patchNode = CurrentAIGraphData
//            .PatchNode(node_id: UUID().uuidString,
//                       node_name: .init(value: .patch(patch)))
//            
//            guard let upstreamStateCoordinate = self
//                .createConnectedPatchData(interactionPatchNodeId: patchNode.node_id,
////                                          createdPatchesAtThisNode: &createdPatchesAtThisNode,
//                                          patchConnections: &patchConnections) else {
//                return
//            }
//            
//            // Update layer assignment for node
//            customPatchInputValues.append(
//                .init(patch_input_coordinate: .init(node_id: patchNode.node_id,
//                                                    port_index: 0),
//                      value: layerId.uuidString,
//                      value_type: .init(value: .interactionId))
//            )
//            
//            // Update view state connections
//            viewStatePatchConnections.updateValue(upstreamStateCoordinate,
//                                                  forKey: self.mutatedStateVar)
//            
////            // Update (possibly new) patch
////            createdPatchesAtThisNode.updateValue(patchNode, forKey: patch)
////            
////            // Output coordinates to return
////            result.updateValue(upstreamStateCoordinate,
////                               forKey: viewEvent.mutatedStateVar)
////        
////        // Add any created patch nodes to the native nodes list
////        createdPatchesAtThisNode.values.forEach { patchNode in
//            nativePatchNodes.updateValue(patchNode,
//                                         forKey: patchNode.node_id)
////        }
//    }
//}

// Closures expected in patch Swift code
enum SwiftPatchClosureType {
    case swiftPatchLogic([(String, SwiftPatchCodeType)])
//    case jsNodeDeclaration(AIGraphData_V0.PreprocessedJSPatchNode)
    case viewEvent(SwiftPatchViewEvent)
}

struct SwiftPatchViewEvent {
    let viewEvent: SyntaxViewEvent
    let codeStatements: [(String, SwiftPatchCodeType)]
}

indirect enum SwiftPatchCodeType {
    case expression(SwiftPatchCodeExpression)
    case subscriptType(SwiftPatchCodeType, Int)
    case swiftFunctionScript(String)
    case viewBuilderScript(String)
    case error(SwiftUISyntaxError)
}

/// Expressions expected in patch Swift code. The idea here being we can create a tree of syntax that, with a string-keyed dictionary, can track any reference in code.
enum SwiftPatchCodeExpression {
    case patchNodeInit(SwiftPatchNodeCode)
    case portValuesInit([SyntaxViewModifierArgumentType])
    case ref(String)
    case jsRef(SwiftJsNodeCode)
//    case jsNodeDeclaration(AIGraphData_V0.PreprocessedJSPatchNode)
}

extension SwiftPatchCodeExpression {
    func createSwiftUICode() -> String {
        switch self {
        case .ref(let string):
            return string
        default:
            fatalErrorIfDebug("not yet supported")
            return ""
        }
    }
}

struct SwiftPatchNodeCode {
    let patch: Patch
    let ports: [SwiftPatchCodeType]
}

struct SwiftJsNodeCode {
    let fnName: String
    let ports: [SwiftPatchCodeType]
}

//enum PatchNodeInputPort {
//    case portValue(PortValueCodeType)
//    case ref(String)
//    case subscriptRef(String, Int)
//}

// Types of values expected in Swift code
//enum PortValueCodeType {
//    case value(PortValueDescription)
//    case ref(String)
//    case memberAccessRef(MemberAccessExprSyntax)
//}

extension Array where Element == (String, SwiftParserInitializerType) {
    func getSwiftPatchCodeTypes() throws -> [(String, SwiftPatchCodeType)] {
        try self.compactMap { data -> (String, SwiftPatchCodeType)? in
            guard let result = try data.1.getSwiftPatchCodeType() else {
                fatalErrorIfDebug()
                return nil
            }
            return (data.0, result)
        }
    }
}

extension SwiftParserInitializerType {
    func getSwiftPatchCodeType() throws -> SwiftPatchCodeType? {
        switch self {
        case .patchNode(let patchNodeData):
            guard let patchData = try patchNodeData.createPatchCodeExpr() else {
                return nil
            }
            
            return .expression(patchData)
            
        case .subscriptRef(let subscriptData):
            switch subscriptData.subscriptType {
            case .patchNode(let patchNodeData):
                guard let patchData = try patchNodeData.createPatchCodeExpr() else {
                    return nil
                }
                
                return .subscriptType(.expression(patchData), subscriptData.portIndex)
                
            case .ref(let refName):
                return .subscriptType(.expression(.ref(refName)), subscriptData.portIndex)
            }
            
        case .patchNodeRef(let string):
            return .expression(.ref(string))
            
        case .stateMutation(let mutationData):
            switch mutationData {
            case .subscriptRef(let subscriptData):
                return try SwiftParserInitializerType.subscriptRef(subscriptData)
                    .getSwiftPatchCodeType()
                
            case .patchNodeRef(let patchNodeRef):
                return .expression(.ref(patchNodeRef))
                
            case .declrRef:
                return try mutationData.getSwiftPatchCodeType()
                
            case .arraySyntax(let arraySyntax):
                guard arraySyntax.elements.count == 1,
                      let firstElem = arraySyntax.elements.first else {
                    // Only know of count sof 1 so far
                    fatalErrorIfDebug()
                    return nil
                }
                
                // Find what we're parsing
                guard let funcExpr = firstElem.expression.as(FunctionCallExprSyntax.self) else {
                    // Check if nested array
                    guard let nestedArrayExpr = firstElem.expression.as(ArrayExprSyntax.self) else {
                        return nil
                    }
                    
                    return try SwiftParserInitializerType
                        .stateMutation(.arraySyntax(nestedArrayExpr))
                        .getSwiftPatchCodeType()
                }
                
                let args: ViewConstructorType
                do {
                    args = try SwiftUIViewVisitor.parseArguments(from: funcExpr)
                } catch let error as SwiftUISyntaxError {
                    return .error(error)
                } catch {
                    fatalErrorIfDebug(error.localizedDescription)
                    return nil
                }
                
                guard let defaultArgs = args.defaultArgs else {
                    fatalErrorIfDebug()
                    return nil
                }
                
                return .expression(.portValuesInit(defaultArgs.map(\.value)))
//                let gestureArg: String?
//                
//                // A little hacky--if PortValueDescription of position type, return a packed variable
//                if (defaultArgs[safe: 1]?.value.simpleValue?.contains("position") ?? false) {
//                    // TODO: see if position or translation
//                    gestureArg = "position"
//                }
//                
//                else {
//                    // Find the property that's read from the gesture param
//                    gestureArg = defaultArgs.compactMap { arg -> String? in
//                        //                            guard let paramVarName = onChangeHandler.paramVars.first,
//                        guard let paramVarName = viewEventParam,
//                              let memberAccess = arg.value.firstMemberAccess else {
//                            return nil
//                        }
//                        
//                        var propertyString = memberAccess.trimmedDescription
//                        let prefixStr = "\(paramVarName)."
//                        
//                        if propertyString.hasPrefix(prefixStr) {
//                            propertyString = String(propertyString.dropFirst(prefixStr.count))
//                        }
//                        
//                        return propertyString
//                        
//                    }.first
//                }
//                
//                let viewEventData = LayerDataViewEvent(viewEvent: viewEvent,
//                                                       gestureArg: gestureArg,
//                                                       mutatedStateVar: varName)
//                
//                viewEventData
//                    .updateInteractionData(layerId: viewEventLayerId,
//                                           nativePatchNodes: &nativePatchNodes,
//                                           customPatchInputValues: &customPatchInputValues,
//                                           viewStatePatchConnections: &viewStatePatchConnections,
//                                           patchConnections: &patchConnections)
                
            default:
                return nil
            }
            
        case .jsNodeScript(let script):
            return .swiftFunctionScript(script)
            
        case .viewBuilder(let script):
            return .viewBuilderScript(script)
            
        case .declrRef(let ref):
            return .expression(.ref(ref))
                
        case .arraySyntax:
            return nil
        }
    }
}

extension Dictionary where Key == String, Value == SwiftPatchCodeType {
    func getUpstreamPatchPortConnectionData(expr: SwiftPatchCodeExpression,
                                            varName: String,
                                            portIndex: Int? = nil,
                                            varNameToCode: [String: SwiftPatchCodeType],
                                            existingStateVarConnections: [String: [NodeIOCoordinate]],
                                            nodesDict: [UUID: NodeEntity],
                                            viewEvent: SyntaxViewEvent?) throws -> [PatchSyntaxResultType] {
        switch expr {
        case .portValuesInit(let array):
            // TODO: look here for handling args
            
            guard let pvDescription = array.first else {
                fatalErrorIfDebug()
                return []
            }
            
            return try pvDescription.derivePortValues(viewEvent: viewEvent)
            
            // TODO: bake in the syntax logic from port values into upstream SwiftPatchCode logic
//            switch portValuesResults.first {
//            case .value(let pvDescription):
//                let value = try PortValue(from: pvDescription)
//                return [
//                    .portData(.values([value]))
//                ]
//                
//            case .stateRef(let ref):
//                return try self
//                    .getUpstreamPatchPortConnectionData(
//                        expr: .ref(ref),
//                        varName: varName,
//                        portIndex: portIndex,
//                        varNameToCode: varNameToCode,
//                        existingStateVarConnections: existingStateVarConnections,
//                        nodesDict: nodesDict,
//                        viewEvent: viewEvent)
//                
//            case .stateRefInViewEvent(let memberAccessData):
//                // TODO: this is how we handle member access data in state ref
//                return memberAccessData.memberAccess
//                    .createConnectedPatchData(viewEvent: memberAccessData.viewEvent,
//                                              varName: varName,
//                                              nodesDict: nodesDict)
//            
//            case .none:
//                throw SwiftUISyntaxError.portValueDataDecodingFailure
//            }
        
        case .ref(let ref):
            let portIndex = portIndex ?? 0
            
            // Check if deterministic ID leads to existing node. If false, we're dealing with layer state update from a view event gesture
            let inferredId = deterministicUUID(from: ref)
            if nodesDict.keys.contains(inferredId) {
                return [
                    .portData(.upstreamConnection(.init(portId: portIndex,
                                                        nodeId: inferredId)))
                ]
            } else if let upstreamStateVarCoordinate = existingStateVarConnections.get(ref)?.first {
                // Connection to some interaction patch node
                return [
                    .portData(.upstreamConnection(upstreamStateVarCoordinate))
                ]
            } else if let upstreamRef = self.get(ref) {
                // Fallback explores if this ref points to another ref
                switch upstreamRef {
                case .expression(let expr):
                    return try self
                        .getUpstreamPatchPortConnectionData(
                            expr: expr,
                            varName: varName,
                            portIndex: portIndex,
                            varNameToCode: varNameToCode,
                            existingStateVarConnections: existingStateVarConnections,
                            nodesDict: nodesDict,
                            viewEvent: viewEvent)
                    
                case .subscriptType(let subscriptType, let newPortIndex):
                    switch subscriptType {
                    case .expression(let subscriptExpr):
                        return try self
                            .getUpstreamPatchPortConnectionData(
                                expr: subscriptExpr,
                                varName: varName,
                                portIndex: newPortIndex,
                                varNameToCode: varNameToCode,
                                existingStateVarConnections: existingStateVarConnections,
                                nodesDict: nodesDict,
                                viewEvent: viewEvent)
                        
                    default:
                        fatalErrorIfDebug()
                        return [.portData(.values([.number(.zero)]))]
                    }
                    
                default:
                    fatalErrorIfDebug()
                    return [.portData(.values([.number(.zero)]))]
                }
            } else {
                // Return upstream connection
                let nodeId = deterministicUUID(from: ref)
                
                // If this fails--a node wasn't made that should have been created
                assertInDebug(nodesDict.keys.contains(nodeId))
                
                return [
                    .portData(.upstreamConnection(.init(portId: portIndex,
                                                        nodeId: nodeId)))
                ]
            }
        
        case .patchNodeInit(let patchNodeData):
            guard let portIndex = portIndex else {
                fatalErrorIfDebug()
                return []
            }
            
            // If a subscript is accessing a patch node instantiation then we need to:
            // 1. create the node, and
            // 2. set a output coordinate at this variable statement
            var patchNodeResult = try patchNodeData
                .defaultNodeEntityData(varName: varName,
                                       varNameToCode: varNameToCode,
                                       groupNodeId: nil,
                                       existingStateVarConnections: existingStateVarConnections,
                                       nodesDict: nodesDict,
                                       viewEvent: viewEvent)
            
            let outputCoordinate = NodeIOCoordinate(portId: portIndex,
                                                    nodeId: deterministicUUID(from: varName))
            
            patchNodeResult.append(.portData(.upstreamConnection(outputCoordinate)))
            return patchNodeResult
            
        case .jsRef:
            fatalErrorIfDebug("Not expected here")
            return [.portData(.values([.number(.zero)]))]
            
//            guard let portIndex = portIndex else {
//                fatalErrorIfDebug()
//                return .values([.number(.zero)])
//            }
//            
//            return .upstreamConnection(.init(portId: portIndex,
//                                             nodeId: nodeId))
        }
    }
    
//    func getUpstreamPatchPortConnectionType(varName: String,
//                                            portIndex: Int? = nil) throws -> NodeConnectionType {
//        guard let value = self.get(varName) else {
//            return .values([.number(.zero)])
//        }
//        
//        return try self
//            .getUpstreamPatchPortConnectionData(varName: varName,
//                                                value: value,
//                                                portIndex: portIndex)
//    }
       
//    @MainActor
//    func getUpstreamPatchPortConnectionData(varName: String,
//                                            portIndex: Int? = nil,
//                                            varNameToCode: [String: SwiftPatchCodeType],
//                                            existingStateVarConnections: [String: NodeIOCoordinate],
//                                            groupNodeId: UUID?,
//                                            nodesDict: [UUID: NodeEntity],
//                                            viewEvent: SyntaxViewEvent?) throws -> [PatchSyntaxResultType] {
//        guard let value = self.get(varName) else {
//            return [.portData(.values([.number(.zero)]))]
//        }
//        
//        return try self
//            .getUpstreamPatchPortConnectionData(value: value,
//                                                varName: varName,
//                                                portIndex: portIndex,
//                                                varNameToCode: varNameToCode,
//                                                existingStateVarConnections: existingStateVarConnections,
//                                                groupNodeId: groupNodeId,
//                                                nodesDict: nodesDict,
//                                                viewEvent: viewEvent)
//    }
     
    func getUpstreamPatchPortConnectionData(value: SwiftPatchCodeType,
                                            varName: String,
                                            portIndex: Int? = nil,
                                            varNameToCode: [String: SwiftPatchCodeType],
                                            existingStateVarConnections: [String: [NodeIOCoordinate]],
                                            nodesDict: [UUID: NodeEntity],
                                            viewEvent: SyntaxViewEvent?) throws -> [PatchSyntaxResultType] {
        switch value {
        case .expression(let expr):
            return try self.getUpstreamPatchPortConnectionData(
                expr: expr,
                varName: varName,
                portIndex: portIndex,
                varNameToCode: varNameToCode,
                existingStateVarConnections: existingStateVarConnections,
                nodesDict: nodesDict,
                viewEvent: viewEvent)
        
        case .subscriptType(let swiftPatchCodeType, let int):
            // Nested port indices (aka a 2D access) not supported
            assertInDebug(portIndex == nil)
            
            switch swiftPatchCodeType {
            case .expression(let expr):
                return try self
                    .getUpstreamPatchPortConnectionData(
                        expr: expr,
                        varName: varName,
                        portIndex: int,
                        varNameToCode: varNameToCode,
                        existingStateVarConnections: existingStateVarConnections,
                        nodesDict: nodesDict,
                        viewEvent: viewEvent)
                
                
            case .error(let error):
                throw error
                
            default:
                fatalErrorIfDebug()
                return [.portData(.values([.number(.zero)]))]
            }
        
        case .error(let swiftUISyntaxError):
            throw swiftUISyntaxError
            
        default:
            fatalErrorIfDebug()
            return [.portData(.values([.number(.zero)]))]
        }
    }
}

// Result type for patch node declaration in Swift, which could contain nested patch data within its input variables.
struct SwiftPatchNodeInputsResult {
    let ports: [NodePortInputEntity]
    
    // Separated data that's inferred from ports, i.e. separate patch node creation
    let otherData: [PatchSyntaxResultType]
}

//struct SwiftPatchNodeResult {
//    let node: NodeEntity
//    
//    // Separated data that's inferred from ports, i.e. separate patch node creation
//    let otherData: [PatchSyntaxResultType]
//}

extension Array where Element == SwiftPatchCodeType {
    func createSchemaList(nodeId: UUID,
                          varNameToCode: [String: SwiftPatchCodeType],
                          existingStateVarConnections: [String: [NodeIOCoordinate]],
                          nodesDict: [UUID: NodeEntity],
                          viewEvent: SyntaxViewEvent?) throws -> SwiftPatchNodeInputsResult {
        var otherData = [PatchSyntaxResultType]()
        
        let portData: [NodePortInputEntity] = try self.enumerated()
            .map { (portIndex, portData) in
                let coordinate = NodeIOCoordinate(
                    portId: portIndex,
                    nodeId: nodeId)
                
                let portDataResult = try varNameToCode
                    .getUpstreamPatchPortConnectionData(
                        value: portData,
                        varName: "",    // can ignore
                        varNameToCode: varNameToCode,
                        existingStateVarConnections: existingStateVarConnections,
                        nodesDict: nodesDict,
                        viewEvent: viewEvent)
                
                // We always expect the relevant port data to be at the end
                guard let lastItem = portDataResult.last,
                      let connectionType = lastItem.portData else {
                    fatalErrorIfDebug()
                    return .init(id: coordinate,
                                 portData: .values([.number(0)]))
                }
                
                otherData += portDataResult.dropLast()
                
                return .init(id: coordinate,
                             portData: connectionType)
            }
        
        return .init(ports: portData,
                     otherData: otherData)
    }
}

//extension Array where Element == PatchSyntaxResultType {
//    var portData: NodeConnectionType? {
//        guard let firstResult = self.first else {
//            return nil
//        }
//        
//        assertInDebug(self.count == 1)
//        
//        switch firstResult {
//        case .portData(let connectionType):
//            return connectionType
//            
//        default:
//            return nil
//        }
//    }
//}

extension SwiftPatchCodeType {
    func createSwiftUICode() -> String {
        switch self {
        case .expression(let expr):
            return expr.createSwiftUICode()
        
        default:
            fatalErrorIfDebug("not yet supported")
            return ""
        }
    }
    
    var jsScript: String? {
        switch self {
        case .swiftFunctionScript(let string):
            return string
            
        default:
            return nil
        }
    }
}

extension SwiftPatchClosureType {
    var viewEvent: SyntaxViewEvent? {
        switch self {
        case .viewEvent(let viewEvent):
            return viewEvent.viewEvent
            
        default:
            return nil
        }
    }
}

struct PatchSyntaxNodeResult {
    let id: UUID
    let kind: NodeKind
    var nodeType: NodeType?
}

struct PatchSyntaxPortValuesResult {
    let inputCoordinate: NodeIOCoordinate
    let values: PortValues
}

struct PatchSyntaxJSResult {
    let id: UUID
    let settings: JavaScriptNodeSettings
}

// TODO: move
enum PatchSyntaxResultType {
    // Refrain from NodeEntity because we don't want to create a dupe later and overwrite data
    case node(PatchSyntaxNodeResult)
    
    // Port value settings for a node's input
    case portValues(PatchSyntaxPortValuesResult)
    
    // Used when code instantiates a reference or value to some patch node with an index
    case portData(NodeConnectionType)
    
    case connection(PortEdgeData)
    
    // State reads
    case connectionToLayerInput(String)
    
    // State writes (var name, patch node output)
    case stateWrite(String, NodeIOCoordinate)
    
    case jsSettings(PatchSyntaxJSResult)
}

extension PatchSyntaxResultType {
    var portData: NodeConnectionType? {
        switch self {
        case .portData(let connectionType):
            return connectionType
            
        case .connection(let edge):
            // assumption here is that the `to` property is going "here"
            return .upstreamConnection(edge.from)
            
        default:
            return nil
        }
    }
    
    var portValues: [PortValue]? {
        switch self {
        case .portValues(let result):
            return result.values
            
        default:
            return nil
        }
    }
    
    var value: PortValue? {
        switch self {
        case .portValues(let portValues):
            return portValues.values.first
        case .portData(let nodeConnectionType):
            return nodeConnectionType.values?.first
        default:
            return nil
        }
    }
}

// TODO: move
extension SwiftPatchNodeCode {
    func defaultNodeEntityData(varName: String,
                               varNameToCode: [String: SwiftPatchCodeType],
                               groupNodeId: UUID?,
                               existingStateVarConnections: [String: [NodeIOCoordinate]],
                               nodesDict: [UUID: NodeEntity],
                               viewEvent: SyntaxViewEvent?,
                               jsSettings: JavaScriptNodeSettings? = nil) throws -> [PatchSyntaxResultType] {
        let nodeId = deterministicUUID(from: varName)
        
        let portData = try self
            .ports
            .createSchemaList(nodeId: nodeId,
                              varNameToCode: varNameToCode,
                              existingStateVarConnections: existingStateVarConnections,
                              nodesDict: nodesDict,
                              viewEvent: viewEvent)
        
        let node = self.patch.defaultNodeEntity(nodeId: nodeId,
                                                ports: portData.ports,
                                                nodesDict: nodesDict,
                                                jsSettings: jsSettings)
        
        let nodeResults = node.nodeTypeEntity.patchNodeEntity?.createAIPatchSyntaxResults() ?? []
        
        var actionsList = portData.otherData
        actionsList += nodeResults
        return actionsList
    }
}

// TODO: move
import CryptoKit
func deterministicUUID(from name: String) -> UUID {
    let data = Data(name.precomposedStringWithCanonicalMapping.utf8)
    let digest = SHA256.hash(data: data)
    var bytes = Data(digest.prefix(16))
    // Mark as "random" style with RFC variant (helps tooling)
    bytes[6] = (bytes[6] & 0x0F) | 0x40  // pretend version 4
    bytes[8] = (bytes[8] & 0x3F) | 0x80
    return bytes.withUnsafeBytes { buf in
        let b = buf.bindMemory(to: UInt8.self)
        return UUID(uuid: (b[0],b[1],b[2],b[3], b[4],b[5], b[6],b[7], b[8],b[9], b[10],b[11],b[12],b[13],b[14],b[15]))
    }
}

extension Layer {
    @MainActor
    func createDefaultLayerNodeEntity(nodeId: UUID,
                                      layerGroupId: UUID?) -> LayerNodeEntity {
        let graphNode = self.layerGraphNode
        var layerNodeEntity = LayerNodeEntity(nodeId: nodeId,
                                              layer: self,
                                              hasSidebarVisibility: true,
                                              layerGroupId: layerGroupId)
        
        graphNode.inputDefinitions.forEach { inputDefinition in
            let defaultValue = inputDefinition.getDefaultValue(for: self)
            
            // Create default unpacked port data
            let unpackedData = (0..<UnpackedPortType.allCases.count).map { unpackedPort in
                LayerInputDataEntity(inputPort: .values([defaultValue]))
            }
            
            layerNodeEntity[keyPath: inputDefinition.schemaPortKeyPath] = .init(
                packedData: .init(inputPort: .values([defaultValue])),
                unpackedData: unpackedData
            )
        }
        
        return layerNodeEntity
    }
}

extension Patch {
    func createDefaultIOValues(nodeIO: NodeIO,
                               nodeType: NodeType? = nil) -> PortValuesList {
        let graphNode = self.graphNode
        // Create port entities from node definition
        let definitions = graphNode.rowDefinitions(for: nodeType ?? graphNode.defaultUserVisibleType)
        
        switch nodeIO {
        case .input:
            return definitions
                .inputs
                .enumerated()
                .map { portIndex, inputDefinition in
                    return inputDefinition.defaultValues
                }
            
        case .output:
            return definitions
                .outputs
                .enumerated()
                .map { portIndex, outputDefinition in
                    return [outputDefinition.value]
                }
        }
    }
    
    func defaultNodeEntity(nodeId: UUID,
                           ports: [NodePortInputEntity]? = nil,
                           nodesDict: [UUID: NodeEntity],
                           jsSettings: JavaScriptNodeSettings? = nil) -> NodeEntity {
        var nodeType: NodeType? = self.graphNode.defaultUserVisibleType
        let portEntities: [NodePortInputEntity]
        
        let canvasEntity = CanvasNodeEntity(position: .zero,
                                            zIndex: .zero,
                                            parentGroupNodeId: nil)
        
        if let ports = ports {
            portEntities = ports
            
            // Find default node type
            // Derive node type
            nodeType = self.deriveNodeValueType(portEntities: ports,
                                                nodesDict: nodesDict)
        } else {
            let inputsValues = self.createDefaultIOValues(nodeIO: .input)
            
            // Create port entities from node definition
            portEntities = inputsValues
                .enumerated()
                .map { portIndex, values in
                    let id = NodeIOCoordinate(portId: portIndex,
                                              nodeId: nodeId)
                    return NodePortInputEntity(
                        id: id,
                        portData: .values(values))
                }
        }
        
        let patchNodeEntity = PatchNodeEntity(
            id: nodeId,
            patch: self,
            inputs: portEntities,
            canvasEntity: canvasEntity,
            userVisibleType: nodeType,
            splitterNode: nil,
            mathExpression: nil,
            javaScriptNodeSettings: jsSettings)
        
        let node = NodeEntity(id: nodeId,
                              nodeTypeEntity: .patch(patchNodeEntity),
                              title: jsSettings?.suggestedTitle ?? "")
        return node
    }
}

extension PatchNodeEntity {
    func createAIPatchSyntaxResults() -> [PatchSyntaxResultType] {
        let nodeResult: [PatchSyntaxResultType] = [
            .node(.init(id: self.id,
                        kind: .patch(self.patch),
                        nodeType: self.userVisibleType)),
        ]
        
        let inputResults: [PatchSyntaxResultType] = self.inputs.enumerated().map { portId, portData in
            switch portData.portData {
            case .values(let values):
                return .portValues(.init(inputCoordinate: .init(portId: portId,
                                                                nodeId: self.id),
                                         values: values))
                
            case .upstreamConnection(let upstreamCoordinate):
                return .connection(.init(from: upstreamCoordinate,
                                         to: .init(portId: portId,
                                                   nodeId: self.id)))
            }
        }
        
        let jsSettings: [PatchSyntaxResultType] = self.javaScriptNodeSettings != nil ? [
            .jsSettings(.init(id: self.id,
                              settings: self.javaScriptNodeSettings!))
        ] : []
        
        return nodeResult + inputResults + jsSettings
    }
}

extension NodeEntity {
    mutating func updateInputData(_ portData: NodeConnectionType,
                                  at index: NodeIOCoordinate,
                                  nodesDict: [UUID: NodeEntity]) {
        switch self.nodeTypeEntity {
        case .patch(var patchNode):
            guard let portId = index.portId else {
                fatalErrorIfDebug()
                return
            }
            
            // Determine if we need to extend inputs
            if portId >= patchNode.inputs.count {
                let defaultValues = patchNode.patch.rowDefinitions(for: patchNode.userVisibleType).inputs.last?.defaultValues ?? [.number(.zero)]
                
                (patchNode.inputs.count..<portId + 1).forEach { newPortId in
                    patchNode.inputs.append(.init(id: .init(portId: newPortId,
                                                            nodeId: self.id),
                                                  portData: .values(defaultValues)))
                }
            }
            
            guard var inputData = patchNode.inputs[safe: portId] else {
                fatalErrorIfDebug()
                return
            }
            
            inputData.portData = portData
            patchNode.inputs[portId] = inputData
            
            // Determine node type
            let nodeType = patchNode.patch
                .deriveNodeValueType(portEntities: patchNode.inputs,
                                     nodesDict: nodesDict)
            let newPatchNode = PatchNodeEntity(id: patchNode.id,
                                               patch: patchNode.patch,
                                               inputs: patchNode.inputs,
                                               canvasEntity: patchNode.canvasEntity,
                                               userVisibleType: nodeType,
                                               splitterNode: patchNode.splitterNode,
                                               mathExpression: patchNode.mathExpression,
                                               javaScriptNodeSettings: patchNode.javaScriptNodeSettings)
            
            self.nodeTypeEntity = .patch(newPatchNode)
            
        case .layer(var layerNode):
            guard let layerInputType = index.layerInput else {
                fatalErrorIfDebug()
                return
            }
            
            layerNode.updateInputData(portData, at: layerInputType)
            self.nodeTypeEntity = .layer(layerNode)
            
        default:
            fatalErrorIfDebug()
        }
    }
}

extension SwiftPatchCodeType {
    @MainActor
    func derivePatchData(document: StitchDocumentViewModel,
                         varName: String?,
                         varNameToCode: [String: SwiftPatchCodeType],
                         viewEvent: SyntaxViewEvent?,
                         existingStateVarConnections: [String: [NodeIOCoordinate]],
                         nodesDict: [UUID: NodeEntity]) async throws -> [PatchSyntaxResultType] {
        guard let aiManager = document.aiManager else {
            fatalErrorIfDebug()
            return []
        }
        
        switch self {
        case .expression(let codeType):
            switch codeType {
            case .patchNodeInit(let patchNodeData):
                guard let varName = varName else {
                    fatalErrorIfDebug()
                    return []
                }
                
                let list = try patchNodeData
                    .defaultNodeEntityData(varName: varName,
                                           varNameToCode: varNameToCode,
                                           groupNodeId: nil,
                                           existingStateVarConnections: existingStateVarConnections,
                                           nodesDict: nodesDict,
                                           viewEvent: viewEvent)
                return list
            
            case .ref(let varName):
                guard let refCode = varNameToCode.get(varName) else {
                    // TODO: will likely fail with port value if used
                    
                    fatalErrorIfDebug()
                    return []
                }
                
                // recursion
                return try await refCode.derivePatchData(
                    document: document,
                    varName: varName,
                    varNameToCode: varNameToCode,
                    viewEvent: viewEvent,
                    existingStateVarConnections: existingStateVarConnections,
                    nodesDict: nodesDict)
            
            case .jsRef(let jsData):
                guard let sourceCode = varNameToCode.get(jsData.fnName)?
                    .jsScript,
                      let varName = varName else {
                    fatalErrorIfDebug()
                    return []
                }

                // Get AI info
                let jsNodeRequest = AIJSNodeSettingsFromScritptRequest(existingScript: sourceCode)
                
                let jsSettings = try await jsNodeRequest
                    .request(document: document,
                             aiManager: aiManager)
                
                // TODO: double check empty list below

                return try SwiftPatchNodeCode(patch: .javascript,
                                              ports: [])
                .defaultNodeEntityData(varName: varName,
                                       varNameToCode: varNameToCode,
                                       groupNodeId: nil,
                                       existingStateVarConnections: existingStateVarConnections,
                                       nodesDict: nodesDict,
                                       viewEvent: viewEvent,
                                       jsSettings: jsSettings)
            
            case .portValuesInit(let args):
                // Check for PortValueDescription
                guard let firstArg = args.first else {
                    fatalErrorIfDebug()
                    return []
                }
                
                return try SyntaxViewName
                    .derivePortValues(from: firstArg,
                                      varName: varName,
                                      viewEvent: viewEvent,
                                      nodesDict: nodesDict)
            }
        
        case .subscriptType(let subscriptCodeType, let portIndex):
            guard let varName = varName else {
                fatalErrorIfDebug()
                return []
            }
            
            // Return an upstream connection
            switch subscriptCodeType {
            case .expression(let expr):
                let result = try varNameToCode
                    .getUpstreamPatchPortConnectionData(
                        expr: expr,
                        varName: varName,
                        portIndex: portIndex,
                        varNameToCode: varNameToCode,
                        existingStateVarConnections: existingStateVarConnections,
                        nodesDict: nodesDict,
                        viewEvent: viewEvent)

                return result
                
            default:
                fatalErrorIfDebug()
                return []
            }
            
//            switch subscriptCodeType {
//            case .expression(let expr):
//                switch expr {
//                case .ref(let refName):
//                    // Find upstream node
//                    let upstreamNodeId = deterministicUUID(from: refName)
//                    fatalError()
//                    
////                    guard let upstreamNode = varNameToCode.get(refName)?.derivePatchData(document: document,
//                
//                default:
//                    fatalErrorIfDebug("Wasn't expected here")
//                    return []
//                }
//            
//            case .error(let swiftUISyntaxError):
//                throw swiftUISyntaxError
//            
//            default:
//                fatalErrorIfDebug("Wasn't expected here")
//                return []
//            }
            
        case .error(let error):
            throw error
            
        default:
            fatalErrorIfDebug("Wasn't expected here")
            return []
        }
    }
}

extension Array where Element == (String, SwiftParserInitializerType) {
    func get(_ name: String) -> SwiftParserInitializerType? {
        self.first { $0.0 == name }?.1
    }
}

extension Array where Element == SwiftPatchClosureType {
    @MainActor
    func derivePatchNodes(document: StitchDocumentViewModel) async -> SwiftSyntaxPatchActionsResult {
        var result = SwiftSyntaxPatchActionsResult(nodes: [],
                                                   stateVarConnections: [:],
                                                   caughtErrors: [])
        
        for closureType in self {
            let existingNodesDict = result.nodes.reduce(into: [:]) { result, node in
                result.updateValue(node, forKey: node.id)
            }

            switch closureType {
            case .swiftPatchLogic(let codeStatements):
                
                let patchResult = await codeStatements
                    .derivePatchNodes(document: document,
                                      existingStateVarConnections: result.stateVarConnections,
                                      existingNodesDict: existingNodesDict,
                                      viewEvent: nil)
                result += patchResult
            
            case .viewEvent(let swiftPatchViewEvent):
                // Create node for view event
                let viewEventData = swiftPatchViewEvent.viewEvent
//                let patch = viewEventData.type.patch
//                
//                // Start with default node
//                var nodeEntity = patch.defaultNode(id: viewEventData.interactionPatchNodeId,
//                                                          position: .zero,
//                                                          zIndex: .zero,
//                                                          graphDelegate: document.graph)
//                    .createSchema()
//                
//                guard var patchNodeEntity = nodeEntity.nodeTypeEntity.patchNodeEntity else {
//                    fatalErrorIfDebug()
//                    continue
//                }
//                
//                patchNodeEntity.inputs[0].portData = .values([.assignedLayer(.init(viewEventData.layerId))])
//                nodeEntity.nodeTypeEntity = .patch(patchNodeEntity)
                
                // Get data from closure actions
                let closureActionsResult = await swiftPatchViewEvent
                    .codeStatements
                    .derivePatchNodes(document: document,
                                      existingStateVarConnections: result.stateVarConnections,
                                      existingNodesDict: existingNodesDict,
                                      viewEvent: viewEventData)
                
//                closureActionsResult.nodes = [nodeEntity] + closureActionsResult.nodes

                result += closureActionsResult
            }
        }
        
        return result
    }
}

extension Dictionary where Key == String, Value == [NodeIOCoordinate] {
    mutating func updateValue(_ value: NodeIOCoordinate, forKey key: String) {
        var currentValues = self.get(key) ?? []
        currentValues.append(value)
        self = self.updatedValue(currentValues, forKey: key)
    }
}

extension Dictionary where Key == UUID, Value == NodeEntity {
    
    // TODO: state var connections would be updated here, take copied code and set breakpoints
    
    mutating func updateWithEventData(_ event: PatchSyntaxResultType,
                                      layerInputCoordinate: NodeIOCoordinate?,
                                      varName: String?,
                                      stateVarConnections: inout [String: [NodeIOCoordinate]]) {
        switch event {
        case .node(let nodeResult):
            // Skip if node already made
            guard self.get(nodeResult.id) == nil else { return }
            
            switch nodeResult.kind {
            case .patch(let patch):
                let nodeEntity = patch
                    .defaultNodeEntity(nodeId: nodeResult.id,
                                       nodesDict: self)
                
                self.updateValue(nodeEntity,
                                 forKey: nodeEntity.id)
                
            default:
                fatalErrorIfDebug("not yet supported")
            }
            
        case .portData(let portData):
            switch portData {
            case .upstreamConnection(let upstreamCoordinate):
                guard let varName = varName else {
                    fatalErrorIfDebug()
                    return
                }
                
                // Update state var connections so we know which layer is pointed to by this variable name
                stateVarConnections.updateValue(upstreamCoordinate,
                                                forKey: varName)
                
            case .values:
                break
            }
            
            // Layer data case
            if let layerInputCoordinate = layerInputCoordinate {
                guard let layerInputType = layerInputCoordinate.keyPath,
                      var layerNodeEntity = self.get(layerInputCoordinate.nodeId)?.layerNodeEntity else {
                    fatalErrorIfDebug()
                    return
                }
                    
                layerNodeEntity.updateInputData(portData,
                                                at: layerInputType)
                self[layerInputCoordinate.nodeId]?.nodeTypeEntity = .layer(layerNodeEntity)
            }
            
        case .connection(let portEdgeData):
            // Update already created node with an upstream connection
            guard var toNode = self.get(portEdgeData.to.nodeId) else {
                fatalErrorIfDebug()
                return
            }
            
            let updatedPort = NodeConnectionType.upstreamConnection(portEdgeData.from)
            
            switch toNode.nodeTypeEntity {
            case .patch(var patchNode):
                guard let inputPortIndex = portEdgeData.to.portId,
                      toNode.inputs[safe: inputPortIndex] != nil else {
                    fatalErrorIfDebug()
                    return
                }
                
                patchNode.inputs[inputPortIndex].portData = updatedPort
                toNode.nodeTypeEntity = .patch(patchNode)
                
            case .layer(var layerNode):
                guard let keyPath = portEdgeData.to.keyPath else {
                    fatalErrorIfDebug()
                    return
                }
                
                layerNode.updateInputData(updatedPort, at: keyPath)
                toNode.nodeTypeEntity = .layer(layerNode)
                
            default:
                fatalErrorIfDebug()
                return
            }
            
            self.updateValue(toNode, forKey: toNode.id)
        
        case .connectionToLayerInput(let stateName):
            // Get upstream patch data from variable name
            guard let upstreamPatchCoordinates = stateVarConnections
                .get(stateName),
                  let layerInputCoordinate = layerInputCoordinate else {
                fatalErrorIfDebug()
                return
            }
            
            // Multiple upstream coordinates means an unpacking scenario
            if upstreamPatchCoordinates.count > 1 {
                upstreamPatchCoordinates.enumerated().forEach { index, upstreamPatchCoordinate in
                    var layerInputCoordinate = layerInputCoordinate
                    guard let unapckedPortType = UnpackedPortType(rawValue: index),
                          var layerKeyPath = layerInputCoordinate.keyPath else {
                        fatalErrorIfDebug()
                        return
                    }
                    
                    layerKeyPath.portType = .unpacked(unapckedPortType)
                    layerInputCoordinate = .init(portType: .keyPath(layerKeyPath),
                                                 nodeId: layerInputCoordinate.nodeId)
                    
                    // Recursively call with extrapolated upstream patch data
                    let event = PatchSyntaxResultType.connection(.init(from: upstreamPatchCoordinate,
                                                                       to: layerInputCoordinate))
                    return self
                        .updateWithEventData(event,
                                             layerInputCoordinate: layerInputCoordinate,
                                             varName: stateName,
                                             stateVarConnections: &stateVarConnections)
                }
            }
            
            // Packed scenario
            else {
                guard let upstreamPatchCoordinate = upstreamPatchCoordinates.first else {
                    fatalErrorIfDebug()
                    return
                }
                
                // Recursively call with extrapolated upstream patch data
                let event = PatchSyntaxResultType.connection(.init(from: upstreamPatchCoordinate,
                                                                   to: layerInputCoordinate))
                return self
                    .updateWithEventData(event,
                                         layerInputCoordinate: layerInputCoordinate,
                                         varName: stateName,
                                         stateVarConnections: &stateVarConnections)
            }
            
        case .portValues(let data):
            guard var nodeEntity = self.get(data.inputCoordinate.nodeId) else {
                fatalErrorIfDebug()
                return
            }
            
            nodeEntity.updateInputData(.values(data.values),
                                       at: data.inputCoordinate,
                                       nodesDict: self)
            self.updateValue(nodeEntity, forKey: nodeEntity.id)
            
        case .jsSettings(let data):
            guard var nodeEntity = self.get(data.id),
                  let patchNode = nodeEntity.patchNodeEntity else {
                fatalErrorIfDebug()
                return
            }
            
            let newPatchNode = PatchNodeEntity(id: patchNode.id,
                                               patch: patchNode.patch,
                                               inputs: patchNode.inputs,
                                               canvasEntity: patchNode.canvasEntity,
                                               userVisibleType: patchNode.userVisibleType,
                                               splitterNode: patchNode.splitterNode,
                                               mathExpression: patchNode.mathExpression,
                                               javaScriptNodeSettings: data.settings)
                
            nodeEntity.nodeTypeEntity = .patch(newPatchNode)
            self.updateValue(nodeEntity, forKey: nodeEntity.id)
        
        case .stateWrite(let varName, let upstreamOutputCoordinate):
            stateVarConnections.updateValue(upstreamOutputCoordinate, forKey: varName)
        }
    }
}

extension Array where Element == (String, SwiftPatchCodeType) {
    @MainActor
    func derivePatchNodes(document: StitchDocumentViewModel,
                          existingStateVarConnections: [String: [NodeIOCoordinate]],
                          existingNodesDict: [UUID: NodeEntity],
                          viewEvent: SyntaxViewEvent?) async -> SwiftSyntaxPatchActionsResult {
        // Create dictionary of self
        let varNameToCode = self.reduce(into: [String: SwiftPatchCodeType]()) { result, data in
            result.updateValue(data.1, forKey: data.0)
        }
        
        // Instantiate dictionary of nodes to return as array later
        var nodesDict = [UUID: NodeEntity]()
        
        // Tracks connections to state variables, used as layer inputs later
        var stateVarConnections = [String: [NodeIOCoordinate]]()
        
        var caughtErrors = [SwiftUISyntaxError]()
        
        // Create patch nodes and input values
        for (varName, code) in self {
            do {
                let mergedStateVarConnections = existingStateVarConnections
                    .merging(stateVarConnections) { $1 }
                let mergedNodesDict = existingNodesDict
                    .merging(nodesDict) { $1 }
                             
                let events = try await code.derivePatchData(
                    document: document,
                    varName: varName,
                    varNameToCode: varNameToCode,
                    viewEvent: viewEvent,
                    existingStateVarConnections: mergedStateVarConnections,
                    nodesDict: mergedNodesDict)
                
                for event in events {
                    nodesDict.updateWithEventData(event,
                                                  layerInputCoordinate: nil,
                                                  varName: varName,
                                                  stateVarConnections: &stateVarConnections)
                }

            } catch let error as SwiftUISyntaxError {
                caughtErrors.append(error)
            } catch {
                fatalErrorIfDebug(error.localizedDescription)
                log("deriveStitchActions: error.localizedDescription: \(error.localizedDescription)")
                continue
            }
        }
        
        return .init(nodes: [NodeEntity](nodesDict.values),
                     stateVarConnections: stateVarConnections,
                     caughtErrors: caughtErrors)
    }
    
//    @MainActor
//    func deriveStitchActions(existingData: SwiftSyntaxPatchActionsResult?,
//                             viewEventData: (SyntaxViewEvent, UUID, String?)? = nil) -> SwiftSyntaxPatchActionsResult {
//        var newResult = existingData
//        
//        // MARK: data to be returned
//        var caughtErrors: [SwiftUISyntaxError] = existingData?.caughtErrors ?? []
//        var nativePatchNodes = (existingData ?? SwiftSyntaxPatchActionsResult())
//            .actions.native_patches.reduce(into: [String: CurrentAIGraphData.PatchNode]()) { result, patchNode in
//                result.updateValue(patchNode, forKey: patchNode.node_id)
//            }
//        var nativePatchValueTypeSettings = (existingData ?? SwiftSyntaxPatchActionsResult()).actions.native_patch_value_type_settings.reduce(into: [String: CurrentAIGraphData.NativePatchNodeValueTypeSetting]()) { result, settings in
//            result.updateValue(settings, forKey: settings.node_id)
//        }
//        var patchConnections = existingData?.actions.patch_connections ?? []
//        var customPatchInputValues = existingData?.actions.custom_patch_input_values ?? []
//        var preprocessedJSNodes = existingData?.actions.javascript_patches ?? []
//        
//        // MARK: data we use as tracking
//        // Maps some variable name to a node ID string
//        var varNameIdMap = [String : String]()
//        
//        // Maps any declarations made of top-level outputs
//        var varNameOutputPortMap = [String : SwiftParserSubscript]()
//        
//        // Maps patch functions references
//        var varNamePatchNodeRefMap = [String : String]()
//        
//        // Tracks a variable name for each JS function name
//        var varNameJsFnMap = [String : String]()
//        
//        // Tracks
////        var viewEventProps = [String]()
//        
//        // Because patch data is decoded before layer data, we don't yet know the destination ports for layer edges, therefore, we just track the source patch to some state variable
//        var viewStatePatchConnections = existingData?.viewStatePatchConnections ?? [:]
//        
//        // Create interaction patch nodes from layer data
////        let stateVarToInteractionOutputsMap = layers.createStateVarToInteractionNodeMap(
////            nativePatchNodes: &nativePatchNodes,
////            customPatchInputValues: &customPatchInputValues,
////            viewStatePatchConnections: &viewStatePatchConnections,
////            patchConnections: &patchConnections
////        )
//        
//        // First pass:
//        // 1. Create patch nodes
//        // 2. Make mappings of var names to specific data
//        for (varName, initializerType) in self {
//            switch initializerType {
//            case .patchNode(let patchNodeData):
//                let newPatchNode = patchNodeData
//                    .createStitchData(varName: varName,
//                                      varNameIdMap: &varNameIdMap,
//                                      varNameJsFnMap: &varNameJsFnMap)
//                nativePatchNodes.updateValue(newPatchNode,
//                                             forKey: newPatchNode.node_id)
//                
//            case .subscriptRef(let subscriptData):
//                // Track top-level bindings of some output port data
//                varNameOutputPortMap.updateValue(subscriptData, forKey: varName)
//                
//                switch subscriptData.subscriptType {
//                case .patchNode(let patchNodeData):
//                    // Track more patch nodes
//                    let newPatchNode = patchNodeData
//                        .createStitchData(varName: varName,
//                                          varNameIdMap: &varNameIdMap,
//                                          varNameJsFnMap: &varNameJsFnMap)
//                    nativePatchNodes.updateValue(newPatchNode,
//                                                 forKey: newPatchNode.node_id)
//                    
//                case .ref:
//                    continue
//                }
//                
//            case .patchNodeRef(let patchNodeRef):
//                varNamePatchNodeRefMap.updateValue(patchNodeRef, forKey: varName)
//                
//            case .stateMutation(let mutationData):
//                // Save outputs that are assigned to this variable
//                switch mutationData {
//                case .subscriptRef(let subscriptData):
//                    varNameOutputPortMap.updateValue(subscriptData, forKey: varName)
//                    
//                case .patchNodeRef(let patchNodeRef):
//                    varNamePatchNodeRefMap.updateValue(patchNodeRef,
//                                                       forKey: varName)
//                    
//                    // TODO: add case here where we do the custom patch node parsing
//                case .arraySyntax(let arraySyntax):
//                    // Find what we're parsing
//                    guard let (viewEvent, viewEventLayerId, viewEventParam) = viewEventData,
//                          let funcExpr = arraySyntax.elements.first?.expression.as(FunctionCallExprSyntax.self) else {
//                        break
//                    }
//                    
//                    let args: ViewConstructorType
//                    do {
//                        args = try SwiftUIViewVisitor.parseArguments(from: funcExpr)
//                    } catch let error as SwiftUISyntaxError {
//                        caughtErrors.append(error)
//                        break
//                    } catch {
//                        fatalErrorIfDebug(error.localizedDescription)
//                        break
//                    }
//                    
//                    guard let defaultArgs = args.defaultArgs else {
//                        break
//                    }
//                    
//                    let gestureArg: String?
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
//                            //                            guard let paramVarName = onChangeHandler.paramVars.first,
//                            guard let paramVarName = viewEventParam,
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
//                            
//                        }.first
//                    }
//                    
//                    let viewEventData = LayerDataViewEvent(viewEvent: viewEvent,
//                                                           gestureArg: gestureArg,
//                                                           mutatedStateVar: varName)
//                    
//                    viewEventData
//                        .updateInteractionData(layerId: viewEventLayerId,
//                                               nativePatchNodes: &nativePatchNodes,
//                                               customPatchInputValues: &customPatchInputValues,
//                                               viewStatePatchConnections: &viewStatePatchConnections,
//                                               patchConnections: &patchConnections)
//                    
//                default:
//                    break
//                }
//                
//            case .jsNodeScript, .declrRef, .arraySyntax, .viewBuilder:
//                // Skipping here
//                break
//            }
//        }
//        
//        // Second pass: derive custom values and edges
//        for (varName, initializerType) in self {
//            // Recursively calls argument data
//            do {
//                try initializerType
//                    .parseStitchActions(varName: varName,
//                                        varNameIdMap: varNameIdMap,
//                                        varNameOutputPortMap: varNameOutputPortMap,
//                                        customPatchInputValues: &customPatchInputValues,
//                                        varNamePatchNodeRefMap: varNamePatchNodeRefMap,
////                                        stateVarToInteractionOutputsMap: stateVarToInteractionOutputsMap,
//                                        nativePatchNodes: nativePatchNodes,
//                                        patchConnections: &patchConnections,
//                                        viewStatePatchConnections: &viewStatePatchConnections,
//                                        nativePatchValueTypeSettings: &nativePatchValueTypeSettings,
//                                        preprocessedJSNodes: &preprocessedJSNodes,
//                                        varNameJsFnMap: &varNameJsFnMap)
//            } catch let error as SwiftUISyntaxError {
//                caughtErrors.append(error)
//            } catch {
//                fatalErrorIfDebug(error.localizedDescription)
//            }
//        }
//        
//        return .init(actions: AIGraphData_V0
//            .PatchData(javascript_patches: preprocessedJSNodes,
//                       native_patches: Array<CurrentAIGraphData.PatchNode>(nativePatchNodes.values),
//                       native_patch_value_type_settings: Array<CurrentAIGraphData.NativePatchNodeValueTypeSetting>(nativePatchValueTypeSettings.values),
//                       patch_connections: patchConnections,
//                       custom_patch_input_values: customPatchInputValues),
//                     viewStatePatchConnections: viewStatePatchConnections,
//                     caughtErrors: caughtErrors)
//    }
}

extension Array where Element == String {
    /// Derives actions from an array of script strings.
    @MainActor
    func deriveStitchActions() -> SwiftSyntaxLayerActionsResult {
        let actionsResults = self.flatMap { script in
            let result = SwiftUIViewVisitor.parseSwiftUICode(script)
            
            let actionsResults = result.viewStack.compactMap { syntaxView in
                syntaxView.deriveStitchActions(bindingDeclarations: result.bindingDeclarations)
            }
            
            return actionsResults
        }
        
        return .init(actions: actionsResults.flatMap(\.actions),
                     caughtErrors: actionsResults.flatMap(\.caughtErrors))
    }
    
    /// Extracts SyntaxView objects from overlay script strings
    func extractOverlaySyntaxViews() -> [SyntaxView] {
        return self.flatMap { script in
            let result = SwiftUIViewVisitor.parseSwiftUICode(script, context: .overlayContent)
            return result.viewStack
        }
    }
    
    /// Extracts SyntaxView objects from background script strings
    func extractBackgroundSyntaxViews() -> [SyntaxView] {
        return self.flatMap { script in
            let result = SwiftUIViewVisitor.parseSwiftUICode(script, context: .overlayContent)
            return result.viewStack
        }
    }
}

extension SyntaxView {
    @MainActor
    func deriveStitchActions(bindingDeclarations: [(String, SwiftParserInitializerType)]) -> SwiftSyntaxLayerActionsResult? {
        // Tracks all silent errors
        var silentErrors = [SwiftUISyntaxError]()
        
        // Recurse into children first (DFS), we might use this data for nested scenarios like ScrollView
        var childResults = self.children.deriveStitchActions(bindingDeclarations: bindingDeclarations)
        
        // Find any possible overlay or background modifiers
        let backgroundModifierScripts = self.modifiers.getClosureScripts(for: .background)
        let overlayModifierScripts = self.modifiers.getClosureScripts(for: .overlay)
        
        // Transform view structure if overlay or background modifiers are present
        let transformedView: SyntaxView
        let hasOverlayClosures = !overlayModifierScripts.isEmpty
        let overlayArgumentViews = self.modifiers.getOverlayArgumentViews(for: .overlay)
        let hasOverlayArguments = !overlayArgumentViews.isEmpty
        
        let hasBackgroundClosures = !backgroundModifierScripts.isEmpty
        let backgroundArgumentViews = self.modifiers.getBackgroundArgumentViews(for: .background)
        let hasBackgroundArguments = !backgroundArgumentViews.isEmpty
        
        if hasOverlayClosures || hasOverlayArguments {
            // Extract overlay content as SyntaxView objects from both sources
            var overlayChildren: [SyntaxView] = []
            
            // Add children from closure scripts (overlay { ... } form)
            if hasOverlayClosures {
                overlayChildren += overlayModifierScripts.extractOverlaySyntaxViews()
            }
            
            // Add children from function arguments (overlay(View) form)
            if hasOverlayArguments {
                overlayChildren += overlayArgumentViews
            }
            
            // Create ZStack with base view (without overlay modifiers) and overlay children
            let baseViewWithoutOverlay = self.removingModifiers(ofType: .overlay)
            transformedView = baseViewWithoutOverlay.wrappedInZStack(withOverlayChildren: overlayChildren)
        } else if hasBackgroundClosures || hasBackgroundArguments {
            // Extract background content as SyntaxView objects from both sources
            var backgroundChildren: [SyntaxView] = []
            
            // Add children from closure scripts (background { ... } form)
            if hasBackgroundClosures {
                backgroundChildren += backgroundModifierScripts.extractBackgroundSyntaxViews()
            }
            
            // Add children from function arguments (background(View) form)
            if hasBackgroundArguments {
                backgroundChildren += backgroundArgumentViews
            }
            
            // Create ZStack with background children first, then base view (without background modifiers)
            let baseViewWithoutBackground = self.removingModifiers(ofType: .background)
            transformedView = baseViewWithoutBackground.wrappedInZStack(withBackgroundChildren: backgroundChildren)
        } else {
            transformedView = self
        }
        
        // If we transformed the view, recursively process the ZStack
        if transformedView.name == "ZStack" && (hasOverlayClosures || hasOverlayArguments || hasBackgroundClosures || hasBackgroundArguments) {
            return transformedView.deriveStitchActions(bindingDeclarations: bindingDeclarations)
        }
        
        // Continue with original processing for non-overlay/background cases
        // Both overlays and backgrounds are now handled in the transformation above
        // Only process background modifiers if they weren't already transformed
        let backgroundLayerData: SwiftSyntaxLayerActionsResult
        if hasBackgroundClosures || hasBackgroundArguments {
            // Backgrounds were already transformed, no additional processing needed
            backgroundLayerData = .init(actions: [], caughtErrors: [])
        } else {
            // Old background processing for backwards compatibility
            backgroundLayerData = backgroundModifierScripts.deriveStitchActions()
        }
        silentErrors += backgroundLayerData.caughtErrors
        
        guard let nameType = SyntaxNameType.from(self.name) else {
            // Check for custom view builder fn
            guard let initializer = bindingDeclarations.get(self.name),
                  let viewBuilderFn = initializer.viewBuilderScript else {
                silentErrors.append(SwiftUISyntaxError.unsupportedSyntaxViewName(self.name))
//                fatalErrorIfDebug()
                log("Could not derive?")
                return nil
            }
            
            // Parse script
            let scriptResult = SwiftUIViewVisitor.parseSwiftUICode(viewBuilderFn)
            let result = scriptResult
                .viewStack.deriveStitchActions(bindingDeclarations: scriptResult.bindingDeclarations)
            
            let actions = result.actions + backgroundLayerData.actions
            
            return .init(actions: actions,
                         caughtErrors: result.caughtErrors + silentErrors)
        }
        
        switch nameType {
        case .view(let syntaxViewName):
            // Flip the children if we have a ZStack,
            // since "top" layer in Stitch sidebar corresponds to "bottom" of declared-child in SwiftUI ZStack.
            if syntaxViewName == .zStack {
                childResults.actions = childResults.actions.reversed()
                
                // TODO: do we really need to reverse the errors?
                childResults.caughtErrors = childResults.caughtErrors.reversed()
            }
            
            silentErrors += childResults.caughtErrors

            // Map this node
            do {
                let layerDataResult = try syntaxViewName.deriveLayerData(
                    id: self.id,
                    args: self.constructorArguments,
                    modifiers: self.modifiers,
                    childrenLayers: childResults.actions,
                    bindingDeclarations: bindingDeclarations)
                
                silentErrors += layerDataResult.silentErrors
                var layerData = layerDataResult.layerData
                
                guard let layer = layerData.node_name.value.layer else {
                    fatalErrorIfDebug("deriveStitchActions error: no layer found for \(layerData.node_name.value)")
                    // log("deriveStitchActions error: no layer found for \(layerData.node_name.value)")
                    throw SwiftUISyntaxError.layerDecodingFailed
                }
                
                if !layer.isGroupForAI {
                    // Make sure non-grouped layer has no children
                    assertInDebug(childResults.actions.isEmpty)
                    layerData.children = nil
                }
        
                return .init(actions: [layerData] + backgroundLayerData.actions,
                             caughtErrors: silentErrors)
            } catch let error as SwiftUISyntaxError {
                if error.shouldFailSilently {
                    log("deriveStitchActions: silent failure for unsupported layer concept: \(error)")
                    // Silent error for unsupported layers
                    silentErrors.append(error)
                    return .init(actions: childResults.actions + backgroundLayerData.actions,
                                 caughtErrors: silentErrors)
                } else {
                    fatalErrorIfDebug(error.localizedDescription)
                    log("SyntaxView: NOT shouldFailSilently: deriveStitchActions: error.localizedDescription: \(error.localizedDescription)")
                    return nil
                }
            } catch {
                 fatalErrorIfDebug(error.localizedDescription)
                log("SyntaxView: deriveStitchActions: error.localizedDescription: \(error.localizedDescription)")
                return nil
            }
            
        case .value:
            // No view here, just continue
            return nil
        }
    }
}


// https://developer.apple.com/documentation/swiftui/color#Getting-standard-colors
extension Color {
    /// Converts a textual system-color name (“yellow”, “.yellow”, “Color.yellow”)
    /// into a `SwiftUI.Color`. Returns `nil` for unknown names.
    static func fromSystemName(_ raw: String) -> Color? {
        // ── 1. Normalise ────────────────────────────────────────────────────────
        var key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.hasPrefix("Color.") { key.removeFirst("Color.".count) }
        if key.hasPrefix(".")      { key.removeFirst() }

        // ── 2. Lookup ───────────────────────────────────────────────────────────
        switch key.lowercased() {
        case "black":   return .black
        case "blue":    return .blue
        case "brown":   return .brown
        case "clear":   return .clear
        case "cyan":    return .cyan
        case "gray",    // US spelling
             "grey":    // convenience UK spelling
                        return .gray
        case "green":   return .green
        case "indigo":  return .indigo
        case "mint":    return .mint
        case "orange":  return .orange
        case "pink":    return .pink
        case "purple":  return .purple
        case "red":     return .red
        case "teal":    return .teal
        case "white":   return .white
        case "yellow":  return .yellow
        default:        return nil        // not a standard color
        }
    }
}
