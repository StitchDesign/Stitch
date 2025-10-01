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
    var nodes: [NodeEntity]
    
    var stateVarConnections: [String: [NodeIOCoordinate]]
    
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
    func deriveStitchActions(bindingDeclarations: [(String, SwiftParserInitializerType)],
                             document: StitchDocumentViewModel,
                             isStreaming: Bool) async throws -> SwiftSyntaxActionsResult {
        // Extract layer data
        let layerResults = self.viewStack.deriveStitchActions(bindingDeclarations: bindingDeclarations, isStreaming: isStreaming)
        
        let interactionsPatchActionResult = layerResults.actions.getPatchResultsFromViewEvents()
        
        let patchCodeStatements = try SwiftPatchClosureType.swiftPatchLogic(self.bindingDeclarations.getSwiftPatchCodeTypes(isStreaming: isStreaming))

        // Prepend view event data for code from `updateLayerInputs`
        let allPatchCode: [SwiftPatchClosureType] = interactionsPatchActionResult.map { .viewEvent($0) } + [patchCodeStatements]
        
//        let debugPatchStrings = allPatchCode.map { "\($0)" }
//            .joined(separator: "\n")
//        print("PATCH DATA:\n\(debugPatchStrings)")
        
        let patchResult = await allPatchCode.derivePatchNodes(document: document, isStreaming: isStreaming)
                
        return .init(graphData: .init(layer_data_list: layerResults.actions,
                                      patchNodes: patchResult.nodes,
                                      viewStatePatchConnections: patchResult.stateVarConnections),
                     caughtErrors: self.caughtErrors + layerResults.caughtErrors)// + patchResults.caughtErrors)
    }
    
    func deriveStitchActionsSync(bindingDeclarations: [(String, SwiftParserInitializerType)], 
                                isStreaming: Bool) throws -> SwiftSyntaxActionsResult {
        // Extract layer data
        let layerResults = self.viewStack.deriveStitchActions(bindingDeclarations: bindingDeclarations, isStreaming: isStreaming)
        
        let interactionsPatchActionResult = layerResults.actions.getPatchResultsFromViewEvents()
        
        let patchCodeStatements = try SwiftPatchClosureType.swiftPatchLogic(self.bindingDeclarations.getSwiftPatchCodeTypes(isStreaming: isStreaming))

        // Prepend view event data for code from `updateLayerInputs`
        let allPatchCode: [SwiftPatchClosureType] = interactionsPatchActionResult.map { .viewEvent($0) } + [patchCodeStatements]
        
        let patchResult = allPatchCode.derivePatchNodesSync(isStreaming: isStreaming)
                
        return .init(graphData: .init(layer_data_list: layerResults.actions,
                                      patchNodes: patchResult.nodes,
                                      viewStatePatchConnections: patchResult.stateVarConnections),
                     caughtErrors: self.caughtErrors + layerResults.caughtErrors)// + patchResults.caughtErrors)
    }
}

extension Array where Element == SyntaxView {
    func deriveStitchActions(bindingDeclarations: [(String, SwiftParserInitializerType)], 
                           isStreaming: Bool) -> SwiftSyntaxLayerActionsResult {
        var result = SwiftSyntaxLayerActionsResult(actions: [],
                                                   caughtErrors: [])
        
        for viewData in self {
            let actions = viewData.deriveStitchActions(bindingDeclarations: bindingDeclarations, isStreaming: isStreaming)
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

// Closures expected in patch Swift code
enum SwiftPatchClosureType {
    case swiftPatchLogic([(String, SwiftPatchCodeType)])
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
}

extension SwiftPatchCodeExpression {
    func createSwiftUICode(isStreaming: Bool) -> String {
        switch self {
        case .ref(let string):
            return string
        default:
            if !isStreaming {
                fatalErrorIfDebug("not yet supported")
            }
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

extension Array where Element == (String, SwiftParserInitializerType) {
    func getSwiftPatchCodeTypes(isStreaming: Bool) throws -> [(String, SwiftPatchCodeType)] {
        try self.compactMap { data -> (String, SwiftPatchCodeType)? in
            guard let result = try data.1.getSwiftPatchCodeType(isStreaming: isStreaming) else {
                if !isStreaming {
                    fatalErrorIfDebug()
                }
                return nil
            }
            return (data.0, result)
        }
    }
}

extension SwiftParserInitializerType {
    func getSwiftPatchCodeType(isStreaming: Bool) throws -> SwiftPatchCodeType? {
        switch self {
        case .patchNode(let patchNodeData):
            guard let patchData = try patchNodeData.createPatchCodeExpr(isStreaming: isStreaming) else {
                return nil
            }
            
            return .expression(patchData)
            
        case .subscriptRef(let subscriptData):
            switch subscriptData.subscriptType {
            case .patchNode(let patchNodeData):
                guard let patchData = try patchNodeData.createPatchCodeExpr(isStreaming: isStreaming) else {
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
                    .getSwiftPatchCodeType(isStreaming: isStreaming)
                
            case .patchNodeRef(let patchNodeRef):
                return .expression(.ref(patchNodeRef))
                
            case .declrRef:
                return try mutationData.getSwiftPatchCodeType(isStreaming: isStreaming)
                
            case .arraySyntax(let arraySyntax):
                guard arraySyntax.elements.count == 1,
                      let firstElem = arraySyntax.elements.first else {
                    // Only know of count sof 1 so far
                    if !isStreaming {
                        fatalErrorIfDebug()
                    }
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
                        .getSwiftPatchCodeType(isStreaming: isStreaming)
                }
                
                let args: ViewConstructorType
                do {
                    args = try SwiftUIViewVisitor.parseArguments(from: funcExpr,
                                                                 isStreaming: isStreaming)
                } catch let error as SwiftUISyntaxError {
                    return .error(error)
                } catch {
                    if !isStreaming {
                        fatalErrorIfDebug(error.localizedDescription)
                    }
                    return nil
                }
                
                guard let defaultArgs = args.defaultArgs else {
                    if !isStreaming {
                        fatalErrorIfDebug()
                    }
                    return nil
                }
                
                return .expression(.portValuesInit(defaultArgs.map(\.value)))
                
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
                                            viewEvent: SyntaxViewEvent?,
                                            isStreaming: Bool) throws -> [PatchSyntaxResultType] {
        switch expr {
        case .portValuesInit(let array):
            guard let pvDescription = array.first else {
                // fatalErrorIfDebug()
                return []
            }
            
            return try pvDescription.derivePortValues(viewEvent: viewEvent,
                                                      isStreaming: isStreaming)
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
                            viewEvent: viewEvent,
                            isStreaming: isStreaming)
                    
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
                                viewEvent: viewEvent,
                                isStreaming: isStreaming)
                        
                    default:
                        if !isStreaming {
                            fatalErrorIfDebug()
                        }
                        return [.portData(.values([.number(.zero)]))]
                    }
                    
                default:
                    if !isStreaming {
                        fatalErrorIfDebug()
                    }
                    return [.portData(.values([.number(.zero)]))]
                }
            } else {
                // Return upstream connection
                let nodeId = deterministicUUID(from: ref)
                
                // If this fails--a node wasn't made that should have been created
                if !isStreaming {
                    assertInDebug(nodesDict.keys.contains(nodeId))
                }
                
                return [
                    .portData(.upstreamConnection(.init(portId: portIndex,
                                                        nodeId: nodeId)))
                ]
            }
        
        case .patchNodeInit(let patchNodeData):
            guard let portIndex = portIndex else {
                if !isStreaming {
                    fatalErrorIfDebug()
                }
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
                                       viewEvent: viewEvent,
                                       isStreaming: isStreaming)
            
            let outputCoordinate = NodeIOCoordinate(portId: portIndex,
                                                    nodeId: deterministicUUID(from: varName))
            
            patchNodeResult.append(.portData(.upstreamConnection(outputCoordinate)))
            return patchNodeResult
            
        case .jsRef:
            fatalErrorIfDebug("Not expected here")
            return [.portData(.values([.number(.zero)]))]
        }
    }
     
    func getUpstreamPatchPortConnectionData(value: SwiftPatchCodeType,
                                            varName: String,
                                            portIndex: Int? = nil,
                                            varNameToCode: [String: SwiftPatchCodeType],
                                            existingStateVarConnections: [String: [NodeIOCoordinate]],
                                            nodesDict: [UUID: NodeEntity],
                                            viewEvent: SyntaxViewEvent?,
                                            isStreaming: Bool) throws -> [PatchSyntaxResultType] {
        switch value {
        case .expression(let expr):
            return try self.getUpstreamPatchPortConnectionData(
                expr: expr,
                varName: varName,
                portIndex: portIndex,
                varNameToCode: varNameToCode,
                existingStateVarConnections: existingStateVarConnections,
                nodesDict: nodesDict,
                viewEvent: viewEvent,
                isStreaming: isStreaming)
        
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
                        viewEvent: viewEvent,
                        isStreaming: isStreaming)
                
                
            case .error(let error):
                throw error
                
            default:
                if !isStreaming {
                    fatalErrorIfDebug()
                }
                return [.portData(.values([.number(.zero)]))]
            }
        
        case .error(let swiftUISyntaxError):
            throw swiftUISyntaxError
            
        default:
            if !isStreaming {
                fatalErrorIfDebug()
            }
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

extension Array where Element == SwiftPatchCodeType {
    func createSchemaList(nodeId: UUID,
                          varNameToCode: [String: SwiftPatchCodeType],
                          existingStateVarConnections: [String: [NodeIOCoordinate]],
                          nodesDict: [UUID: NodeEntity],
                          viewEvent: SyntaxViewEvent?,
                          isStreaming: Bool) throws -> SwiftPatchNodeInputsResult {
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
                        viewEvent: viewEvent,
                        isStreaming: isStreaming)
                
                // We always expect the relevant port data to be at the end
                guard let lastItem = portDataResult.last,
                      let connectionType = lastItem.portData else {
                    if !isStreaming {
                        fatalErrorIfDebug()
                    }
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

extension SwiftPatchCodeType {
    func createSwiftUICode(isStreaming: Bool) -> String {
        switch self {
        case .expression(let expr):
            return expr.createSwiftUICode(isStreaming: isStreaming)
        
        default:
            if !isStreaming {
                fatalErrorIfDebug("not yet supported")
            }
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
    
    var containsJsRef: Bool {
        switch self {
        case .expression(.jsRef):
            return true
        case .subscriptType(let codeType, _):
            return codeType.containsJsRef
        default:
            return false
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
                               jsSettings: JavaScriptNodeSettings? = nil,
                               isStreaming: Bool) throws -> [PatchSyntaxResultType] {
        let nodeId = deterministicUUID(from: varName)
        
        let portData = try self
            .ports
            .createSchemaList(nodeId: nodeId,
                              varNameToCode: varNameToCode,
                              existingStateVarConnections: existingStateVarConnections,
                              nodesDict: nodesDict,
                              viewEvent: viewEvent,
                              isStreaming: isStreaming)
        
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

extension Layer {
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
                           nodeType providedNodeType: NodeType? = nil,
                           nodesDict: [UUID: NodeEntity],
                           jsSettings: JavaScriptNodeSettings? = nil) -> NodeEntity {
        var nodeType: NodeType? = providedNodeType ?? self.graphNode.defaultUserVisibleType
        let portEntities: [NodePortInputEntity]

        let canvasEntity = CanvasNodeEntity(position: .zero,
                                            zIndex: .zero,
                                            parentGroupNodeId: nil)

        if let ports = ports {
            portEntities = ports

            // Only derive node type if not already provided
            if providedNodeType == nil {
                // Find default node type
                // Derive node type
                nodeType = self.deriveNodeValueType(portEntities: ports,
                                                    nodesDict: nodesDict)
            }
        } else {
            let inputsValues = self.createDefaultIOValues(nodeIO: .input, nodeType: nodeType)

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
                                  nodesDict: [UUID: NodeEntity],
                                  isStreaming: Bool) {
        switch self.nodeTypeEntity {
        case .patch(var patchNode):
            guard let portId = index.portId else {
                if !isStreaming {
                    fatalErrorIfDebug()
                }
                return
            }
            
            // Determine if we need to extend inputs
            if portId >= patchNode.inputs.count {
                
                
                // How are we able to extend inputs before we know the proper derived node type ?
                let defaultValues = patchNode.patch.rowDefinitions(for: patchNode.userVisibleType).inputs.last?.defaultValues ?? [.number(.zero)]
                
                (patchNode.inputs.count..<portId + 1).forEach { newPortId in
                    patchNode.inputs.append(.init(id: .init(portId: newPortId,
                                                            nodeId: self.id),
                                                  portData: .values(defaultValues)))
                }
            }
            
            guard var inputData = patchNode.inputs[safe: portId] else {
                if !isStreaming {
                    fatalErrorIfDebug()
                }
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
                if !isStreaming {
                    fatalErrorIfDebug()
                }
                return
            }
            
            layerNode.updateInputData(portData, at: layerInputType)
            self.nodeTypeEntity = .layer(layerNode)
            
        default:
            if !isStreaming {
                fatalErrorIfDebug()
            }
        }
    }
}

extension SwiftPatchCodeType {
    func derivePatchDataSync(varName: String?,
                            varNameToCode: [String: SwiftPatchCodeType],
                            viewEvent: SyntaxViewEvent?,
                            existingStateVarConnections: [String: [NodeIOCoordinate]],
                            nodesDict: [UUID: NodeEntity],
                            isStreaming: Bool) throws -> [PatchSyntaxResultType] {
        switch self {
        case .expression(let codeType):
            switch codeType {
            case .patchNodeInit(let patchNodeData):
                guard let varName = varName else {
                    if !isStreaming {
                        fatalErrorIfDebug()
                    }
                    return []
                }
                
                let list = try patchNodeData
                    .defaultNodeEntityData(varName: varName,
                                           varNameToCode: varNameToCode,
                                           groupNodeId: nil,
                                           existingStateVarConnections: existingStateVarConnections,
                                           nodesDict: nodesDict,
                                           viewEvent: viewEvent,
                                           isStreaming: isStreaming)
                return list
            
            case .ref(let varName):
                guard let refCode = varNameToCode.get(varName) else {
                    // TODO: will likely fail with port value if used
                    
                    if !isStreaming {
                        fatalErrorIfDebug()
                    }
                    return []
                }
                
                // recursion
                return try refCode.derivePatchDataSync(
                    varName: varName,
                    varNameToCode: varNameToCode,
                    viewEvent: viewEvent,
                    existingStateVarConnections: existingStateVarConnections,
                    nodesDict: nodesDict,
                    isStreaming: isStreaming)
            
            case .jsRef:
                // Return empty for JS references in sync mode - async version will handle this
                return []
            
            case .portValuesInit(let args):
                // Check for PortValueDescription
                guard let firstArg = args.first else {
                    if !isStreaming {
                        fatalErrorIfDebug()
                    }
                    return []
                }
                
                return try SyntaxViewName
                    .derivePortValues(from: firstArg,
                                      varName: varName,
                                      viewEvent: viewEvent,
                                      nodesDict: nodesDict,
                                      isStreaming: isStreaming)
            }
        
        case .subscriptType(let subscriptCodeType, let portIndex):
            guard let varName = varName else {
                if !isStreaming {
                    fatalErrorIfDebug()
                }
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
                        viewEvent: viewEvent,
                        isStreaming: isStreaming)

                return result
                
            default:
                if !isStreaming {
                    fatalErrorIfDebug()
                }
                return []
            }
            
        case .swiftFunctionScript:
            // Can safely ignore as we don't create new nodes from the declaration of a JS script, that only happens when we reference it
            return []
            
        case .error(let error):
            throw error
            
        default:
            if !isStreaming {
//                fatalErrorIfDebug("Wasn't expected here")
                log("Wasn't expected here")
            }
            return []
        }
    }
    
    @MainActor
    func derivePatchData(document: StitchDocumentViewModel,
                         varName: String?,
                         varNameToCode: [String: SwiftPatchCodeType],
                         viewEvent: SyntaxViewEvent?,
                         existingStateVarConnections: [String: [NodeIOCoordinate]],
                         nodesDict: [UUID: NodeEntity],
                         isStreaming: Bool) async throws -> [PatchSyntaxResultType] {
        // Handle the async jsRef case
        if case .expression(.jsRef(let jsData)) = self {
            guard let aiManager = document.aiManager else {
                if !isStreaming {
                    fatalErrorIfDebug()
                }
                return []
            }
            
            guard let sourceCode = varNameToCode.get(jsData.fnName)?
                .jsScript,
                  let varName = varName else {
                if !isStreaming {
                    fatalErrorIfDebug()
                }
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
                                   jsSettings: jsSettings,
                                   isStreaming: isStreaming)
        }
        
        // For all other cases, delegate to the synchronous version
        return try derivePatchDataSync(
            varName: varName,
            varNameToCode: varNameToCode,
            viewEvent: viewEvent,
            existingStateVarConnections: existingStateVarConnections,
            nodesDict: nodesDict,
            isStreaming: isStreaming)
    }
}

extension Sequence {
    func getKeys<T>() -> Set<String> where Element == (String, T) {
        self.map(\.0).toSet
    }
    
    func get<T>(_ name: String) -> T? where Element == (String, T) {
        self.first { $0.0 == name }?.1
    }
}

extension Array where Element == SwiftPatchClosureType {
    func derivePatchNodesSync(isStreaming: Bool) -> SwiftSyntaxPatchActionsResult {
        var result = SwiftSyntaxPatchActionsResult(nodes: [],
                                                   stateVarConnections: [:],
                                                   caughtErrors: [])
        
        for closureType in self {
            let existingNodesDict = result.nodes.reduce(into: [:]) { result, node in
                result.updateValue(node, forKey: node.id)
            }

            switch closureType {
            case .swiftPatchLogic(let codeStatements):
                let patchResult = codeStatements
                    .derivePatchNodesSync(existingStateVarConnections: result.stateVarConnections,
                                         existingNodesDict: existingNodesDict,
                                         viewEvent: nil,
                                         isStreaming: isStreaming)
                result += patchResult
            
            case .viewEvent(let swiftPatchViewEvent):
                let viewEventData = swiftPatchViewEvent.viewEvent
                let closureActionsResult = swiftPatchViewEvent
                    .codeStatements
                    .derivePatchNodesSync(existingStateVarConnections: result.stateVarConnections,
                                         existingNodesDict: existingNodesDict,
                                         viewEvent: viewEventData,
                                         isStreaming: isStreaming)
                result += closureActionsResult
            }
        }
        
        return result
    }
    
    @MainActor
    func derivePatchNodes(document: StitchDocumentViewModel, 
                         isStreaming: Bool) async -> SwiftSyntaxPatchActionsResult {
        // Check if any closure contains async operations
        let hasAsyncOperations = self.contains { closureType in
            switch closureType {
            case .swiftPatchLogic(let codeStatements):
                return codeStatements.contains { (_, code) in code.containsJsRef }
            case .viewEvent(let swiftPatchViewEvent):
                return swiftPatchViewEvent.codeStatements.contains { (_, code) in code.containsJsRef }
            }
        }
        
        if !hasAsyncOperations {
            // Use sync version if no async operations needed
            return derivePatchNodesSync(isStreaming: isStreaming)
        }
        
        var result = SwiftSyntaxPatchActionsResult(nodes: [],
                                                   stateVarConnections: [:],
                                                   caughtErrors: [])
        
        for closureType in self {
            let existingNodesDict = result.nodes.reduce(into: [:]) { result, node in
                result.updateValue(node, forKey: node.id)
            }

            switch closureType {
            case .swiftPatchLogic(let codeStatements):
                
                do {
                    let patchResult = try await codeStatements
                        .derivePatchNodes(document: document,
                                          existingStateVarConnections: result.stateVarConnections,
                                          existingNodesDict: existingNodesDict,
                                          viewEvent: nil,
                                          isStreaming: isStreaming)
                    result += patchResult
                } catch let error as SwiftUISyntaxError {
                    result.caughtErrors.append(error)
                } catch {
                    // Handle other errors if needed
                    log("derivePatchNodes error: \(error.localizedDescription)")
                }
            
            case .viewEvent(let swiftPatchViewEvent):
                let viewEventData = swiftPatchViewEvent.viewEvent
                
                // Get data from closure actions
                do {
                    let closureActionsResult = try await swiftPatchViewEvent
                        .codeStatements
                        .derivePatchNodes(document: document,
                                          existingStateVarConnections: result.stateVarConnections,
                                          existingNodesDict: existingNodesDict,
                                          viewEvent: viewEventData,
                                          isStreaming: isStreaming)
                    
                    result += closureActionsResult
                } catch let error as SwiftUISyntaxError {
                    result.caughtErrors.append(error)
                } catch {
                    // Handle other errors if needed
                    log("derivePatchNodes viewEvent error: \(error.localizedDescription)")
                }
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
    mutating func updateWithEventData(_ event: PatchSyntaxResultType,
                                      layerInputCoordinate: NodeIOCoordinate?,
                                      varName: String?,
                                      stateVarConnections: inout [String: [NodeIOCoordinate]],
                                      isStreaming: Bool) throws {
        switch event {
        case .node(let nodeResult):
            // Skip if node already made
            guard self.get(nodeResult.id) == nil else { return }
            
            switch nodeResult.kind {
            case .patch(let patch):
                let nodeEntity = patch
                    .defaultNodeEntity(nodeId: nodeResult.id,
                                       nodeType: nodeResult.nodeType,
                                       nodesDict: self)

                self.updateValue(nodeEntity,
                                 forKey: nodeEntity.id)
                
            default:
                if !isStreaming {
                    fatalErrorIfDebug("not yet supported")
                }
            }
            
        case .portData(let portData):
            switch portData {
            case .upstreamConnection(let upstreamCoordinate):
                guard let varName = varName else {
                    if !isStreaming {
                        fatalErrorIfDebug()
                    }
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
                    if !isStreaming {
                        fatalErrorIfDebug()
                    }
                    return
                }
                    
                layerNodeEntity.updateInputData(portData,
                                                at: layerInputType)
                self[layerInputCoordinate.nodeId]?.nodeTypeEntity = .layer(layerNodeEntity)
            }
            
        case .connection(let portEdgeData):
            // Update already created node with an upstream connection
            guard var toNode = self.get(portEdgeData.to.nodeId) else {
                if !isStreaming {
                    fatalErrorIfDebug()
                }
                return
            }
            
            let updatedPort = NodeConnectionType.upstreamConnection(portEdgeData.from)
            
            switch toNode.nodeTypeEntity {
            case .patch(var patchNode):
                guard let inputPortIndex = portEdgeData.to.portId,
                      toNode.inputs[safe: inputPortIndex] != nil else {
                    if !isStreaming {
                        fatalErrorIfDebug()
                    }
                    return
                }
                
                patchNode.inputs[inputPortIndex].portData = updatedPort
                toNode.nodeTypeEntity = .patch(patchNode)
                
            case .layer(var layerNode):
                guard let keyPath = portEdgeData.to.keyPath else {
                    if !isStreaming {
                        fatalErrorIfDebug()
                    }
                    return
                }
                
                layerNode.updateInputData(updatedPort, at: keyPath)
                toNode.nodeTypeEntity = .layer(layerNode)
                
            default:
                if !isStreaming {
                    fatalErrorIfDebug()
                }
                return
            }
            
            self.updateValue(toNode, forKey: toNode.id)
        
        case .connectionToLayerInput(let stateName):
            // Get upstream patch data from variable name
            guard let upstreamPatchCoordinates = stateVarConnections
                .get(stateName),
                  let layerInputCoordinate = layerInputCoordinate else {
                throw SwiftUISyntaxError.unexpectedUpstreamLayerCoordinate
            }
            
            // Multiple upstream coordinates means an unpacking scenario
            if upstreamPatchCoordinates.count > 1 {
                try upstreamPatchCoordinates.enumerated().forEach { index, upstreamPatchCoordinate in
                    var layerInputCoordinate = layerInputCoordinate
                    guard let unapckedPortType = UnpackedPortType(rawValue: index),
                          var layerKeyPath = layerInputCoordinate.keyPath else {
                        if !isStreaming {
                            fatalErrorIfDebug()
                        }
                        return
                    }
                    
                    layerKeyPath.portType = .unpacked(unapckedPortType)
                    layerInputCoordinate = .init(portType: .keyPath(layerKeyPath),
                                                 nodeId: layerInputCoordinate.nodeId)
                    
                    // Recursively call with extrapolated upstream patch data
                    let event = PatchSyntaxResultType.connection(.init(from: upstreamPatchCoordinate,
                                                                       to: layerInputCoordinate))
                    return try self
                        .updateWithEventData(event,
                                             layerInputCoordinate: layerInputCoordinate,
                                             varName: stateName,
                                             stateVarConnections: &stateVarConnections,
                                             isStreaming: isStreaming)
                }
            }
            
            // Packed scenario
            else {
                guard let upstreamPatchCoordinate = upstreamPatchCoordinates.first else {
                    if !isStreaming {
                        fatalErrorIfDebug()
                    }
                    return
                }
                
                // Recursively call with extrapolated upstream patch data
                let event = PatchSyntaxResultType.connection(.init(from: upstreamPatchCoordinate,
                                                                   to: layerInputCoordinate))
                return try self
                    .updateWithEventData(event,
                                         layerInputCoordinate: layerInputCoordinate,
                                         varName: stateName,
                                         stateVarConnections: &stateVarConnections,
                                         isStreaming: isStreaming)
            }
            
        case .portValues(let data):
            guard var nodeEntity = self.get(data.inputCoordinate.nodeId) else {
                if !isStreaming {
                    fatalErrorIfDebug()
                }
                return
            }
            
            nodeEntity.updateInputData(.values(data.values),
                                       at: data.inputCoordinate,
                                       nodesDict: self,
                                       isStreaming: isStreaming)
            self.updateValue(nodeEntity, forKey: nodeEntity.id)
            
        case .jsSettings(let data):
            guard var nodeEntity = self.get(data.id),
                  let patchNode = nodeEntity.patchNodeEntity else {
                if !isStreaming {
                    fatalErrorIfDebug()
                }
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
    func derivePatchNodesSync(existingStateVarConnections: [String: [NodeIOCoordinate]],
                             existingNodesDict: [UUID: NodeEntity],
                             viewEvent: SyntaxViewEvent?,
                             isStreaming: Bool) -> SwiftSyntaxPatchActionsResult {
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
                             
                let events = try code.derivePatchDataSync(
                    varName: varName,
                    varNameToCode: varNameToCode,
                    viewEvent: viewEvent,
                    existingStateVarConnections: mergedStateVarConnections,
                    nodesDict: mergedNodesDict,
                    isStreaming: isStreaming)
                
                for event in events {
                    do {
                        try nodesDict.updateWithEventData(event,
                                                          layerInputCoordinate: nil,
                                                          varName: varName,
                                                          stateVarConnections: &stateVarConnections,
                                                          isStreaming: isStreaming)
                    } catch let error as SwiftUISyntaxError {
                        caughtErrors.append(error)
                    } catch {
                        if !isStreaming {
                            fatalErrorIfDebug("derivePatchNodesSync error: \(error.localizedDescription)")
                        }
                    }
                }

            } catch let error as SwiftUISyntaxError {
                caughtErrors.append(error)
            } catch {
                if !isStreaming {
                    fatalErrorIfDebug(error.localizedDescription)
                    log("deriveStitchActions: error.localizedDescription: \(error.localizedDescription)")
                }
                log("deriveStitchActions: error.localizedDescription: \(error.localizedDescription)")
                continue
            }
        }
        
        return .init(nodes: [NodeEntity](nodesDict.values),
                     stateVarConnections: stateVarConnections,
                     caughtErrors: caughtErrors)
    }
    
    @MainActor
    func derivePatchNodes(document: StitchDocumentViewModel,
                          existingStateVarConnections: [String: [NodeIOCoordinate]],
                          existingNodesDict: [UUID: NodeEntity],
                          viewEvent: SyntaxViewEvent?,
                          isStreaming: Bool) async -> SwiftSyntaxPatchActionsResult {
        // Check if any element needs async processing (contains jsRef)
        let hasAsyncOperations = self.contains { (_, code) in
            code.containsJsRef
        }
        
        if !hasAsyncOperations {
            // Use sync version if no async operations needed
            return derivePatchNodesSync(existingStateVarConnections: existingStateVarConnections,
                                       existingNodesDict: existingNodesDict,
                                       viewEvent: viewEvent,
                                       isStreaming: isStreaming)
        }
        
        // Create dictionary of self
        let varNameToCode = self.reduce(into: [String: SwiftPatchCodeType]()) { result, data in
            result.updateValue(data.1, forKey: data.0)
        }
        
        // Instantiate dictionary of nodes to return as array later
        var nodesDict = [UUID: NodeEntity]()
        
        // Tracks connections to state variables, used as layer inputs later
        var stateVarConnections = [String: [NodeIOCoordinate]]()
        
        var caughtErrors = [SwiftUISyntaxError]()
        
        // Create patch nodes and input values with async support
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
                    nodesDict: mergedNodesDict,
                    isStreaming: isStreaming)
                
                for event in events {
                    try nodesDict.updateWithEventData(event,
                                                      layerInputCoordinate: nil,
                                                      varName: varName,
                                                      stateVarConnections: &stateVarConnections,
                                                      isStreaming: isStreaming)
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
}

extension Array where Element == String {
    /// Derives actions from an array of script strings.
    func deriveStitchActions(isStreaming: Bool) -> SwiftSyntaxLayerActionsResult {
        let actionsResults = self.flatMap { script in
            let result = SwiftUIViewVisitor.parseSwiftUICode(script, isStreaming: isStreaming)
            
            let actionsResults = result.viewStack.compactMap { syntaxView in
                syntaxView.deriveStitchActions(bindingDeclarations: result.bindingDeclarations, isStreaming: isStreaming)
            }
            
            return actionsResults
        }
        
        return .init(actions: actionsResults.flatMap(\.actions),
                     caughtErrors: actionsResults.flatMap(\.caughtErrors))
    }
    
    /// Extracts SyntaxView objects from overlay script strings
    func extractOverlaySyntaxViews(isStreaming: Bool) -> [SyntaxView] {
        return self.flatMap { script in
            let result = SwiftUIViewVisitor.parseSwiftUICode(script, context: .overlayContent, isStreaming: isStreaming)
            return result.viewStack
        }
    }
    
    /// Extracts SyntaxView objects from background script strings
    func extractBackgroundSyntaxViews(isStreaming: Bool) -> [SyntaxView] {
        return self.flatMap { script in
            let result = SwiftUIViewVisitor.parseSwiftUICode(script, context: .overlayContent, isStreaming: isStreaming)
            return result.viewStack
        }
    }
}

extension SyntaxView {
    func deriveStitchActions(bindingDeclarations: [(String, SwiftParserInitializerType)], 
                           isStreaming: Bool) -> SwiftSyntaxLayerActionsResult? {
        // Tracks all silent errors
        var silentErrors = [SwiftUISyntaxError]()
        
        // Recurse into children first (DFS), we might use this data for nested scenarios like ScrollView
        var childResults = self.children.deriveStitchActions(bindingDeclarations: bindingDeclarations, isStreaming: isStreaming)
        
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
                overlayChildren += overlayModifierScripts.extractOverlaySyntaxViews(isStreaming: isStreaming)
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
                backgroundChildren += backgroundModifierScripts.extractBackgroundSyntaxViews(isStreaming: isStreaming)
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
            return transformedView.deriveStitchActions(bindingDeclarations: bindingDeclarations, isStreaming: isStreaming)
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
            backgroundLayerData = backgroundModifierScripts.deriveStitchActions(isStreaming: isStreaming)
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
            let scriptResult = SwiftUIViewVisitor.parseSwiftUICode(viewBuilderFn, isStreaming: isStreaming)
            let result = scriptResult
                .viewStack.deriveStitchActions(bindingDeclarations: scriptResult.bindingDeclarations, isStreaming: isStreaming)
            
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
                    bindingDeclarations: bindingDeclarations,
                    isStreaming: isStreaming)
                
                silentErrors += layerDataResult.silentErrors
                var layerData = layerDataResult.layerData
                
                guard let layer = layerData.node_name.value.layer else {
                    if !isStreaming {
                        fatalErrorIfDebug("deriveStitchActions error: no layer found for \(layerData.node_name.value)")
                    }
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
                    if !isStreaming {
                        fatalErrorIfDebug(error.localizedDescription)
                    }
                    log("SyntaxView: NOT shouldFailSilently: deriveStitchActions: error.localizedDescription: \(error.localizedDescription)")
                    return nil
                }
            } catch {
                if !isStreaming {
                    fatalErrorIfDebug(error.localizedDescription)
                }
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
