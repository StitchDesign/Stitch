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

struct SwiftSyntaxLayerActionsResult: Encodable {
    var actions: [CurrentAIGraphData.LayerData]
    var caughtErrors: [SwiftUISyntaxError]
}

struct SwiftSyntaxPatchActionsResult: Encodable {
//    var actions: CurrentAIGraphData.PatchData
    var nodes: [NodeEntity]
    
    var stateVarConnections: [String: NodeIOCoordinate]
    
    // Tracks any upstream patches that connect to some state
    // Key = state variable name
    // Value = upstream coordinate
//    var viewStatePatchConnections: [String : AIGraphData_V0.NodeIndexedCoordinate]
    
    var caughtErrors: [SwiftUISyntaxError]
}

extension SwiftSyntaxPatchActionsResult {
//    init() {
//        self.init(actions: .init(javascript_patches: [],
//                                 native_patches: [],
//                                 native_patch_value_type_settings: [],
//                                 patch_connections: [],
//                                 custom_patch_input_values: []),
//                  viewStatePatchConnections: .init(),
//                  caughtErrors: [])
//    }
    
//    static func + (lhs: Self, rhs: Self) -> Self {
//        var lhs = lhs
//        lhs.actions += rhs.actions
//        lhs.viewStatePatchConnections.merge(rhs.viewStatePatchConnections, uniquingKeysWith: { $1 })
//        lhs.caughtErrors += rhs.caughtErrors
//        return lhs
//    }
//    
//    static func += (lhs: inout Self, rhs: Self) {
//        lhs = lhs + rhs
//    }
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

struct SwiftSyntaxActionsResult: Encodable {
    var graphData: CurrentAIGraphData.GraphData
    
    var caughtErrors: [SwiftUISyntaxError]
}

extension SwiftUIViewParserResult {
    @MainActor
    func deriveStitchActions(bindingDeclarations: [(String, SwiftParserInitializerType)],
                             document: StitchDocumentViewModel) async -> SwiftSyntaxActionsResult {
        // Extract layer data
        let layerResults = self.viewStack.deriveStitchActions(bindingDeclarations: bindingDeclarations)
        
        let interactionsPatchActionResult = layerResults.actions.getPatchResultsFromViewEvents()

        // Prepend view event data for code from `updateLayerInputs`
        let allPatchCode = try! interactionsPatchActionResult + self.bindingDeclarations.getSwiftPatchCodeTypes()
        
        let debugPatchStrings = allPatchCode.map { "\($0)" }
            .joined(separator: "\n")
        print("PATCH DATA:\n\(debugPatchStrings)")
        
        let patchResult = await allPatchCode.derivePatchNodes(document: document)
        
        print(patchResult)
        
//        let patchResults = self.bindingDeclarations.deriveStitchActions(existingData: interactionsPatchActionResult)
        
        return .init(graphData: .init(layer_data_list: layerResults.actions,
                                      patch_data: .init(javascript_patches: [], native_patches: [], native_patch_value_type_settings: [], patch_connections: [], custom_patch_input_values: []),
                                      viewStatePatchConnections: [:]),
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
    func getPatchResultsFromViewEvents() -> [(String, SwiftPatchCodeType)] {
        self.reduce(into: [(String, SwiftPatchCodeType)]()) { result, layerData in
            if let actionsResult = layerData.view_events {
                result += actionsResult
            }
            
            if let children = layerData.children {
                result = children.getPatchResultsFromViewEvents()
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
//    func getAllViewEventsMap(into dict: [UUID: LayerDataViewEvent]? = nil) -> [UUID: LayerDataViewEvent] {
//        self.reduce(into: dict ?? .init()) { result, layerData in
//            layerData.view_events.forEach { viewEvent in
//                if let id = UUID(layerData.node_id) {
//                    result.updateValue(viewEvent, forKey: id)
//                }
//            }
//            
//            if let appendedChildrenResult = layerData.children?.getAllViewEventsMap(into: result) {
//                result = appendedChildrenResult
//            }
//        }
//    }
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
    case swiftPatchLogic([String: SwiftPatchCodeType])
    case jsNodeDeclaration(AIGraphData_V0.PreprocessedJSPatchNode)
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
    case viewEventArg(SyntaxViewEvent)
    case jsRef(SwiftJsNodeCode)
//    case jsNodeDeclaration(AIGraphData_V0.PreprocessedJSPatchNode)
}

struct SwiftPatchNodeCode {
    let nodeId: UUID
    let patch: Patch
    let ports: [SwiftPatchCodeType]
}

struct SwiftJsNodeCode {
    let nodeId = UUID()
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
                
            case .arraySyntax(let arraySyntax):
                guard arraySyntax.elements.count == 1,
                      let firstElem = arraySyntax.elements.first else {
                    // Only know of count sof 1 so far
                    fatalErrorIfDebug()
                    return nil
                }
                
                // Find what we're parsing
                guard let funcExpr = firstElem.expression.as(FunctionCallExprSyntax.self) else {
                    return nil
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
                
        case .arraySyntax, .declrRef:
            return nil
        }
    }
}

extension Dictionary where Key == String, Value == SwiftPatchCodeType {
    func getUpstreamPatchPortConnectionType(expr: SwiftPatchCodeExpression,
                                            portIndex: Int? = nil) throws -> NodeConnectionType {
        switch expr {
        case .portValuesInit(let array):
            guard let pvDescription = array.first else {
                fatalErrorIfDebug()
                return .values([.number(.zero)])
            }
            
            let portValuesResults = try pvDescription.derivePortValues()
            
            // TODO: bake in the syntax logic from port values into upstream SwiftPatchCode logic
            switch portValuesResults.first {
            case .value(let pvDescription):
                let value = try PortValue(from: pvDescription)
                return .values([value])
                
            case .stateRef(let ref):
                return try self
                    .getUpstreamPatchPortConnectionType(varName: ref,
                                                        portIndex: portIndex)
                
            case .none:
                throw SwiftUISyntaxError.portValueDataDecodingFailure
            }
        
        case .ref(let string):
            return try self
                .getUpstreamPatchPortConnectionType(varName: string,
                                                    portIndex: portIndex)
        
        case .patchNodeInit(let patchNodeData):
            guard let portIndex = portIndex else {
                fatalErrorIfDebug()
                return .values([.number(.zero)])
            }
            
            return .upstreamConnection(.init(portId: portIndex,
                                             nodeId: patchNodeData.nodeId))
            
        case .viewEventArg(let viewEvent):
            // Port index should be provided based on the view event
            guard let portIndex = portIndex else {
                fatalErrorIfDebug()
                return .values([.number(.zero)])
            }
            
            fatalError("come back here, read the expression and use `createConnectedPatchData` for determining unpacked scenarios")
            
//            return .upstreamConnection(.init(portId: portIndex,
//                                             nodeId: viewEvent.nodeId))
            
        case .jsRef(let jsNode):
            guard let portIndex = portIndex else {
                fatalErrorIfDebug()
                return .values([.number(.zero)])
            }
            
            return .upstreamConnection(.init(portId: portIndex,
                                             nodeId: jsNode.nodeId))
        }
    }
    
    func getUpstreamPatchPortConnectionType(varName: String,
                                            portIndex: Int? = nil) throws -> NodeConnectionType {
        guard let value = self.get(varName) else {
            return .values([.number(.zero)])
        }
        
        return try self
            .getUpstreamPatchPortConnectionType(value: value,
                                                portIndex: portIndex)
    }
        
    func getUpstreamPatchPortConnectionType(value: SwiftPatchCodeType,
                                            portIndex: Int? = nil) throws -> NodeConnectionType {
        switch value {
        case .expression(let expr):
            return try self.getUpstreamPatchPortConnectionType(expr: expr,
                                                               portIndex: portIndex)
        
        case .subscriptType(let swiftPatchCodeType, let int):
            // Nested port indices (aka a 2D access) not supported
            assertInDebug(portIndex == nil)
            
            switch swiftPatchCodeType {
            case .expression(let expr):
                return try self
                    .getUpstreamPatchPortConnectionType(expr: expr,
                                                        portIndex: int)
                
                
            case .error(let error):
                throw error
                
            default:
                fatalErrorIfDebug()
                return .values([.number(.zero)])
            }
        
        case .error(let swiftUISyntaxError):
            throw swiftUISyntaxError
            
        default:
            fatalErrorIfDebug()
            return .values([.number(.zero)])
        }
    }
}

extension Array where Element == SwiftPatchCodeType {
    func createSchemaList(nodeId: UUID,
                          varNameToCode: [String: SwiftPatchCodeType]) throws -> [NodePortInputEntity] {
        try self.enumerated()
            .map { (portIndex, portData) in
                let coordinate = NodeIOCoordinate(
                    portId: portIndex,
                    nodeId: nodeId)
                
                let _portData = try varNameToCode
                    .getUpstreamPatchPortConnectionType(value: portData)
                
                return .init(id: coordinate,
                             portData: _portData)
            }
    }
}

extension SwiftPatchCodeType {
    var jsScript: String? {
        switch self {
        case .swiftFunctionScript(let string):
            return string
            
        default:
            return nil
        }
    }
    
    var viewEvent: SyntaxViewEvent? {
        switch self {
        case .expression(let expr):
            switch expr {
            case .viewEventArg(let viewEvent):
                return viewEvent
                
            default:
                return nil
            }
            
        default:
            return nil
        }
    }
}

// TODO: move
enum PatchSyntaxResultType {
    case node(NodeEntity)
    case upstreamCoordinate(NodeIOCoordinate)
    case connection(PortEdgeData)
}

// TODO: move
extension SwiftPatchNodeCode {
    @MainActor
    func defaultNodeEntity(varNameToCode: [String: SwiftPatchCodeType],
                           groupNodeId: UUID?) throws -> NodeEntity {
        let portEntities: [NodePortInputEntity] = try self
            .ports
            .createSchemaList(nodeId: self.nodeId,
                              varNameToCode: varNameToCode)
        
        return self.patch.defaultNodeEntity(nodeId: self.nodeId,
                                            ports: portEntities,
                                            groupNodeId: groupNodeId)
    }
}

extension Patch {
    @MainActor
    func defaultNodeEntity(nodeId: UUID,
                           ports: [NodePortInputEntity]? = nil,
                           groupNodeId: UUID?) -> NodeEntity {
        assertInDebug(self.graphNode != nil)
        
        let graphNode = self.graphNode ?? SplitterPatchNode.self
        
        let defaultType = self
            .graphNode?
            .defaultUserVisibleType
        
        let canvasEntity = CanvasNodeEntity(position: .zero,
                                            zIndex: .zero,
                                            parentGroupNodeId: groupNodeId)
        
        let ports = ports ?? graphNode.rowDefinitions(for: defaultType)
            .inputs
            .enumerated()
            .map { portIndex, inputDefinition in
                let id = NodeIOCoordinate(portId: portIndex,
                                          nodeId: nodeId)
                return NodePortInputEntity(
                    id: id,
                    portData: .values(inputDefinition.defaultValues))
            }
        
        let patchNodeEntity = PatchNodeEntity(
            id: nodeId,
            patch: self,
            inputs: ports,
            canvasEntity: canvasEntity,
            userVisibleType: defaultType,
            splitterNode: nil,
            mathExpression: nil,
            javaScriptNodeSettings: nil)
        
        let node = NodeEntity(id: nodeId,
                              nodeTypeEntity: .patch(patchNodeEntity),
                              title: "")
        return node
    }
}

extension SwiftPatchCodeType {
    @MainActor
    func derivePatchData(document: StitchDocumentViewModel,
                         varNameToCode: [String: SwiftPatchCodeType]) async throws -> [PatchSyntaxResultType] {
        let currentGroupContext = document.groupNodeFocused?.groupNodeId
        
        guard let aiManager = document.aiManager else {
            fatalErrorIfDebug()
            return []
        }
        
        switch self {
        case .expression(let codeType):
            switch codeType {
            case .patchNodeInit(let patchNodeData):
                let node = try patchNodeData
                    .defaultNodeEntity(varNameToCode: varNameToCode,
                                       groupNodeId: currentGroupContext)
                return [.node(node)]
            
            case .ref(let varName):
                guard let refCode = varNameToCode.get(varName) else {
                    fatalErrorIfDebug()
                    return []
                }
                
                // recursion
                return try await refCode.derivePatchData(document: document,
                                                         varNameToCode: varNameToCode)
            
            case .viewEventArg(let viewEventData):
                let patch = viewEventData.type.patch
                
                // Start with default node
                var nodeEntity = patch.defaultNode(id: viewEventData.interactionPatchNodeId,
                                                          position: .zero,
                                                          zIndex: .zero,
                                                          graphDelegate: document.graph)
                    .createSchema()
                
                guard var patchNodeEntity = nodeEntity.nodeTypeEntity.patchNodeEntity else {
                    fatalErrorIfDebug()
                    return []
                }
                
                patchNodeEntity.inputs[0].portData = .values([.assignedLayer(.init(viewEventData.layerId))])
                nodeEntity.nodeTypeEntity = .patch(patchNodeEntity)
                
                return [.node(nodeEntity)]
            
            case .jsRef(let jsData):
                let jsNodeId = jsData.nodeId
                let portEntities: [NodePortInputEntity] = try jsData.ports
                    .createSchemaList(nodeId: jsNodeId,
                                      varNameToCode: varNameToCode)
                
                guard let sourceCode = varNameToCode.get(jsData.fnName)?
                    .jsScript else {
                    fatalErrorIfDebug()
                    return []
                }
                
                let canvasEntity = CanvasNodeEntity(position: .zero,
                                                    zIndex: .zero,
                                                    parentGroupNodeId: currentGroupContext)
                
                // Get AI info
                let jsNodeRequest = AIJSNodeSettingsFromScritptRequest(existingScript: sourceCode)
                
                let jsSettings = try await jsNodeRequest
                    .request(document: document,
                             aiManager: aiManager)
                
                let patchNodeEntity = PatchNodeEntity(
                    id: jsNodeId,
                    patch: .javascript,
                    inputs: portEntities,
                    canvasEntity: canvasEntity,
                    userVisibleType: nil,
                    splitterNode: nil,
                    mathExpression: nil,
                    javaScriptNodeSettings: jsSettings)
                
                let node = NodeEntity(id: jsNodeId,
                                      nodeTypeEntity: .patch(patchNodeEntity),
                                      title: jsSettings.suggestedTitle)
                
                return [.node(node)]
            
            case .portValuesInit(let args):
                // Check for member syntax for view event arg, like `g.translation.width`
                // Interaction nodes are already created with the parameter created from a view event, so this logic is here to determine specific connections and if unpack nodes should be made
                guard let memberAccess = args.first?.memberAccess else {
                    return []
                }
                
                let baseString = memberAccess.mostNestedBaseName
                
                guard let viewEvent = varNameToCode.get(baseString)?.viewEvent else {
                    return []
                }
                
                // Drop the argument portion of the argument
                let trimmedMemberAccess = memberAccess.dropInnermostBase()
                
                return viewEvent
                    .createConnectedPatchData(gestureArg: trimmedMemberAccess,
                                              groupNodeId: currentGroupContext)
            }
        
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

extension Array where Element == (String, SwiftPatchCodeType) {
    @MainActor
    func derivePatchNodes(document: StitchDocumentViewModel) async -> SwiftSyntaxPatchActionsResult {
        // Create dictionary of self
        let varNameToCode = self.reduce(into: [String: SwiftPatchCodeType]()) { result, data in
            result.updateValue(data.1, forKey: data.0)
        }
        
        // Instantiate dictionary of nodes to return as array later
        var nodesDict = [UUID: NodeEntity]()
        
        // Tracks connections to state variables, used as layer inputs later
        var stateVarConnections = [String: NodeIOCoordinate]()
        
        var caughtErrors = [SwiftUISyntaxError]()
        
        // Create patch nodes and input values
        for (varName, code) in self {
            do {
                let events = try await code.derivePatchData(document: document,
                                                                varNameToCode: varNameToCode)
                
                for event in events {
                    switch event {
                    case .node(let nodeEntity):
                        nodesDict.updateValue(nodeEntity,
                                              forKey: nodeEntity.id)
                        
                    case .upstreamCoordinate(let upstreamCoordinate):
                        stateVarConnections.updateValue(upstreamCoordinate,
                                                        forKey: varName)
                        
                    case .connection(let portEdgeData):
                        // Update already created node with an upstream connection
                        guard var toNode = nodesDict.get(portEdgeData.to.nodeId),
                              let inputPortIndex = portEdgeData.to.portId,
                              var patchNode = toNode.nodeTypeEntity.patchNodeEntity,
                              var portToUpdate = patchNode.inputs[safe: inputPortIndex] else {
                            fatalErrorIfDebug()
                            continue
                        }
                        
                        portToUpdate.portData = .upstreamConnection(portEdgeData.from)
                        patchNode.inputs[inputPortIndex] = portToUpdate
                        toNode.nodeTypeEntity = .patch(patchNode)
                        nodesDict.updateValue(toNode, forKey: toNode.id)
                    }
                }

            } catch let error as SwiftUISyntaxError {
                caughtErrors.append(error)
            } catch {
                fatalErrorIfDebug(error.localizedDescription)
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
                    return nil
                }
            } catch {
                // fatalErrorIfDebug(error.localizedDescription)
                log(error.localizedDescription)
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
