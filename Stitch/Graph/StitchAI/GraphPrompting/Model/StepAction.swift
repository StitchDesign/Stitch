//
//  StepAction.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/24/25.
//

import Foundation
import StitchSchemaKit

typealias StepActionables = [any StepActionable]

// TODO: enum is probably better than protocol here; protocol is for contract (often: scoping down), enum is for data; the main question is "Do these things need to be equatable / comparable?"; if something needs to support equality comparisons, then it's data, not a contract
protocol StepActionable: Hashable, Codable, Sendable, Identifiable {
    static var stepType: StepType { get }
        
    static func fromStep(_ action: Step) -> Result<Self, StitchAIStepHandlingError>
    
    static func createStructuredOutputs() -> AIGraphCreationStepSchema
    
    /// Lists each property tracked in OpenAI's structured outputs.
    static var structuredOutputsCodingKeys: Set<Step.CodingKeys> { get }
    
    var toStep: Step { get }
    
    @MainActor
    func applyAction(document: StitchDocumentViewModel) -> StitchAIStepHandlingError?
    
    @MainActor
    func removeAction(graph: GraphState, document: StitchDocumentViewModel)
    
    func validate(createdNodes: [NodeId : PatchOrLayer]) -> Result<[NodeId: PatchOrLayer], StitchAIStepHandlingError>
    
    // Maps the Step's node ids (sent to us by OpenAI) to a StitchNode
    func remapNodeIds(nodeIdMap: [StitchAIUUID: NodeId]) -> Self
}

typealias AIStepParsingNodeIdMap = [StitchAIUUID: NodeId]

extension StepActionable {
    var id: Int { self.hashValue }
}

struct StepActionLayerGroupCreated: StepActionable {
    static let stepType: StepType = .sidebarGroupCreated
    
    var nodeId: NodeId
    var children: NodeIdSet
    
    var toStep: Step {
        Step(stepType: Self.stepType,
             nodeId: nodeId,
             children: children)
    }
    
    func remapNodeIds(nodeIdMap: [StitchAIUUID: NodeId]) -> StepActionLayerGroupCreated {
        var copy = self
        
        // Update the node id of the layer group itself...
        copy.nodeId = nodeIdMap.get(.init(value: self.nodeId)) ?? self.nodeId
        
        // ... and its children
        copy.children = copy.children.map({ (childId: NodeId) in
            if let newChildId = nodeIdMap.get(.init(value: childId)) {
                log("StepActionLayerGroupCreated: remapNodeIds: NEW newChildId: \(newChildId)")
                return newChildId
            } else {
                log("StepActionLayerGroupCreated: remapNodeIds: OLD childId: \(childId)")
                return childId
            }
        }).toSet
        
        return copy
    }
    
    static func fromStep(_ action: Step) -> Result<Self, StitchAIStepHandlingError> {
        if let nodeId = action.nodeId?.value, let children = action.children {
            return .success(.init(nodeId: nodeId, children: children))
        }
        return .failure(.stepDecoding(Self.stepType, action))
    }
    
    static func createStructuredOutputs() -> AIGraphCreationStepSchema {
        .init(stepType: .sidebarGroupCreated,
              nodeId: OpenAISchema(type: .string),
              children: OpenAISchemaRef(ref: "NodeIdSet"))
    }
    
    static let structuredOutputsCodingKeys: Set<Step.CodingKeys> = [.stepType, .nodeId, .children]
    
    @MainActor
    func applyAction(document: StitchDocumentViewModel) -> StitchAIStepHandlingError? {
        let layersSidebar = document.visibleGraph.layersSidebarViewModel
        layersSidebar.primary = Set(self.children) // Primarily select the group's chidlren
        layersSidebar.sidebarGroupCreated(id: self.nodeId) // Create the group
        return nil
    }
    
    func removeAction(graph: GraphState, document: StitchDocumentViewModel) {
        let layersSidebar = document.visibleGraph.layersSidebarViewModel
        // `sidebarGroupUncreated` is expected to be called from a UI condition where user has 'primarily selected' a layer group
        layersSidebar.primary = Set([self.nodeId])
        layersSidebar.sidebarGroupUncreated()
    }
    
    func validate(createdNodes: [NodeId : PatchOrLayer]) -> Result<[NodeId: PatchOrLayer], StitchAIStepHandlingError> {
        .success(createdNodes.updatedValue(.layer(.group), forKey: self.nodeId))
    }
}

// "Which properties from `Step` are actually needed by StepType = .addNode ?"


struct StepActionAddNode: StepActionable {
    static let stepType: StepType = .addNode
    
    var nodeId: NodeId
    var nodeName: PatchOrLayerAI

    var toStep: Step {
        Step(stepType: Self.stepType,
             nodeId: nodeId,
             nodeName: nodeName)
    }
    
    func remapNodeIds(nodeIdMap: [StitchAIUUID: NodeId]) -> Self {
        var copy = self
        copy.nodeId = nodeIdMap.get(.init(value: self.nodeId)) ?? self.nodeId
        return copy
    }
    
    static func fromStep(_ action: Step) -> Result<Self, StitchAIStepHandlingError> {
        if let nodeId = action.nodeId?.value,
           let nodeKind = action.nodeName {
            return .success(.init(nodeId: nodeId,
                                  nodeName: nodeKind))
        }
        return .failure(.stepDecoding(Self.stepType, action))
    }
    
    static func createStructuredOutputs() -> AIGraphCreationStepSchema {
        .init(stepType: .addNode,
              nodeId: OpenAISchema(type: .string),
              nodeName: OpenAISchemaRef(ref: "NodeName")
        )
    }
    
    static let structuredOutputsCodingKeys: Set<Step.CodingKeys> = [.stepType, .nodeId, .nodeName]
    
    @MainActor
    func applyAction(document: StitchDocumentViewModel) -> StitchAIStepHandlingError? {
        // log("StepActionAddNode: applyAction: self.nodeId: \(self.nodeId)")
        do {
            let migratedNodeName = try self.nodeName.convert(to: PatchOrLayer.self)
            let _ = document.nodeInserted(choice: migratedNodeName,
                                          nodeId: self.nodeId)

            return nil
        } catch {
            return .typeMigrationFailed(self.nodeName)
        }
    }
    
    func removeAction(graph: GraphState,
                      document: StitchDocumentViewModel) {
        // log("StepActionAddNode: removeAction: self.nodeId: \(self.nodeId)")
        graph.deleteNode(id: self.nodeId,
                         document: document,
                         willDeleteLayerGroupChildren: true)
    }
    
    // TODO: what does `validate` mean here ? Are we "making x valid" or "determining whether x is valid" ?
    func validate(createdNodes: [NodeId : PatchOrLayer]) -> Result<[NodeId: PatchOrLayer], StitchAIStepHandlingError> {
        do {
            let migratedNodeName = try self.nodeName.convert(to: PatchOrLayer.self)
            return .success(createdNodes.updatedValue(migratedNodeName, forKey: self.nodeId))
        } catch {
            return .failure(.typeMigrationFailed(self.nodeName))
        }
    }
}

// See `createLLMStepConnectionAdded`
struct StepActionConnectionAdded: StepActionable {
    static let stepType = StepType.connectNodes
    
    // effectively the 'to port'
    let port: CurrentStep.NodeIOPortType // integer or key path
    var toNodeId: NodeId
    
    let fromPort: Int //NodeIOPortType // integer or key path
    var fromNodeId: NodeId
    
    var toStep: Step {
        Step(
            stepType: Self.stepType,
            port: port,
            fromPort: fromPort,
            fromNodeId: fromNodeId,
            toNodeId: toNodeId
        )
    }
    
    func remapNodeIds(nodeIdMap: [StitchAIUUID: NodeId]) -> Self {
        var copy = self
        
        copy.toNodeId = nodeIdMap.get(.init(value: self.toNodeId)) ?? self.toNodeId
        copy.fromNodeId = nodeIdMap.get(.init(value: self.fromNodeId)) ?? self.fromNodeId

        return copy
    }
    
    static func fromStep(_ action: Step) -> Result<Self, StitchAIStepHandlingError> {
        guard let fromNodeId = action.fromNodeId?.value,
              let toPort = action.port,
              let toNodeId = action.toNodeId?.value else {
            return .failure(.stepDecoding(Self.stepType, action))
        }

        // default to 0 for some legacy actions ?
        let fromPort = action.fromPort ?? 0
        
        return .success(.init(port: toPort,
                              toNodeId: toNodeId,
                              fromPort: fromPort,
                              fromNodeId: fromNodeId))
    }
    
    static func createStructuredOutputs() -> AIGraphCreationStepSchema {
        .init(stepType: .connectNodes,
              port: OpenAIGeneric(types: [OpenAISchema(type: .integer)],
                                  refs: [OpenAISchemaRef(ref: "LayerPorts")]),
              fromPort: OpenAISchema(type: .integer),
              fromNodeId: OpenAISchema(type: .string),
              toNodeId: OpenAISchema(type: .string)
        )
    }
    
    static let structuredOutputsCodingKeys: Set<Step.CodingKeys> = [.stepType, .port, .fromPort, .fromNodeId, .toNodeId]
    
    func createInputPort() throws -> NodeIOCoordinate {
        let migratedPort = try self.port.convert(to: NodeIOPortType.self)
        return .init(portType: migratedPort, nodeId: self.toNodeId)
    }
    
    @MainActor
    func applyAction(document: StitchDocumentViewModel) -> StitchAIStepHandlingError? {
        do {
            let inputPort = try self.createInputPort()
            let edge: PortEdgeData = PortEdgeData(
                from: .init(portType: .portIndex(self.fromPort), nodeId: self.fromNodeId),
                to: inputPort)
            
            let _ = document.visibleGraph.edgeAdded(edge: edge)
            
            // Create canvas node if destination is layer
            if let fromNodeLocation = document.visibleGraph.getNode(self.fromNodeId)?.nonLayerCanvasItem?.position,
               let destinationNode = document.visibleGraph.getNode(self.toNodeId),
               destinationNode.kind.isLayer {
                guard let layerInput = inputPort.keyPath?.layerInput else {
                    // fatalErrorIfDebug()
                    return .actionValidationError("expected layer node keypath but got: \(self.port)")
                }
                
                var position = fromNodeLocation
                position.x += 200
                
                document.addLayerInputToCanvas(node: destinationNode,
                                               layerInput: layerInput,
                                               draggedOutput: nil,
                                               canvasHeightOffset: nil,
                                               position: position)
            }
            
        } catch {
            return .typeMigrationFailed(self.port)
        }
        
        return nil
    }
    
    func removeAction(graph: GraphState, document: StitchDocumentViewModel) {
        do {
            let inputPort = try self.createInputPort()
            graph.removeEdgeAt(input: inputPort)
        } catch {
            fatalErrorIfDebug("Unexpected type conversion error for \(self.port)")
        }
    }
    
    // Note: The protocol's `validate` signature is too broad here; we can only return optionally return `StitchAIStepHandlingError`
    func validate(createdNodes: [NodeId : PatchOrLayer]) -> Result<[NodeId: PatchOrLayer], StitchAIStepHandlingError> {
        let originNode = createdNodes.get(self.fromNodeId)
        let destinationNode = createdNodes.get(self.toNodeId)
        
        guard destinationNode.isDefined else {
            return .failure(.actionValidationError("ConnectNodes: Tried create a connection from node \(self.fromNodeId.debugFriendlyId) to \(self.toNodeId.debugFriendlyId), but the To Node does not yet exist"))
        }
        
        guard let originNode = originNode else {
            return .failure(.actionValidationError("ConnectNodes: Tried create a connection from node \(self.fromNodeId.debugFriendlyId) to \(self.toNodeId.debugFriendlyId), but the From Node does not yet exist"))
        }
        
        guard originNode.asNodeKind.isPatch else {
            return .failure(.actionValidationError("ConnectNodes: Tried create a connection from node \(self.fromNodeId.debugFriendlyId) to \(self.toNodeId.debugFriendlyId), but the From Node was a layer or group"))
        }
        
        return .success(createdNodes)
    }
}

// See: `createLLMStepChangeValueType`
struct StepActionChangeValueType: StepActionable {
    static let stepType = StepType.changeValueType
    
    var nodeId: NodeId
    var valueType: StitchAINodeType
    
    var toStep: Step {
        Step(stepType: Self.stepType,
             nodeId: nodeId,
             valueType: valueType)
    }
    
    func remapNodeIds(nodeIdMap: [StitchAIUUID: NodeId]) -> Self {
        var copy = self
        
        copy.nodeId = nodeIdMap.get(.init(value: self.nodeId)) ?? self.nodeId

        return copy
    }
    
    static func fromStep(_ action: Step) -> Result<Self, StitchAIStepHandlingError> {
        if let nodeId = action.nodeId?.value,
           let valueType = action.valueType {
            return .success(.init(nodeId: nodeId,
                                  valueType: valueType))
        }
        
        return .failure(.stepDecoding(Self.stepType, action))
    }
    
    static func createStructuredOutputs() -> AIGraphCreationStepSchema {
        .init(stepType: .changeValueType,
              nodeId: OpenAISchema(type: .string),
              valueType: OpenAISchemaRef(ref: "ValueType")
        )
    }
    
    static let structuredOutputsCodingKeys: Set<Step.CodingKeys> = [.stepType, .nodeId, .valueType]
    
    @MainActor
    func applyAction(document: StitchDocumentViewModel) -> StitchAIStepHandlingError? {
        do {
            let migratedType = try self.valueType.migrate()
            
            // NodeType etc. for this patch was already validated in `[StepTypeAction].areValidLLMSteps`
            let _ = document.visibleGraph.nodeTypeChanged(nodeId: self.nodeId,
                                                          newNodeType: migratedType,
                                                          activeIndex: document.activeIndex)
        } catch {
            return .typeMigrationFailed(self.valueType)
        }
        
        return nil
    }
    
    func removeAction(graph: GraphState, document: StitchDocumentViewModel) {
        // Do nothing, assume node will be removed
    }
    
    func validate(createdNodes: [NodeId : PatchOrLayer]) -> Result<[NodeId: PatchOrLayer], StitchAIStepHandlingError> {
        guard let patch = createdNodes.get(self.nodeId)?.asNodeKind.getPatch else {
            return .failure(.actionValidationError("ChangeValueType: no patch for node \(self.nodeId.debugFriendlyId)"))
        }
        
        do {
            let migratedType = try self.valueType.migrate()
            
            guard patch.availableNodeTypes.contains(migratedType) else {
                return .failure(.actionValidationError("ChangeValueType: invalid node type \(self.valueType.display) for patch \(patch.defaultDisplayTitle()) on node \(self.nodeId.debugFriendlyId)"))
            }
            
            return .success(createdNodes)
        } catch {
            return .failure(.typeMigrationFailed(self.valueType))
        }
    }
}

// See: `createLLMStepSetInput`
struct StepActionSetInput: StepActionable {
    static let stepType = StepType.setInput
    
    var nodeId: NodeId
    let port: CurrentStep.NodeIOPortType // integer or key path
    var value: CurrentStep.PortValue
    let valueType: StitchAINodeType
    
    // encoding
    var toStep: Step {
        Step(stepType: Self.stepType,
             nodeId: nodeId,
             port: port,
             value: value,
             valueType: value.nodeType)
    }
    
    func remapNodeIds(nodeIdMap: [StitchAIUUID: NodeId]) -> Self {
        var copy = self
        copy.nodeId = nodeIdMap.get(.init(value: self.nodeId)) ?? self.nodeId
        if let interactionId = copy.value.getInteractionId {
            let newId = nodeIdMap.get(.init(value: interactionId)) ?? interactionId
            copy.value = .assignedLayer(CurrentStep.LayerNodeId(newId))
        }
        return copy
    }
    
    static func fromStep(_ action: Step) -> Result<Self, StitchAIStepHandlingError> {
        if let nodeId = action.nodeId?.value,
           let port = action.port,
           let valueType = action.valueType,
           let value = action.value {
            return .success(.init(nodeId: nodeId,
                                  port: port,
                                  value: value,
                                  valueType: valueType))
        }
        
        return .failure(.stepDecoding(Self.stepType, action))
    }
    
    static func createStructuredOutputs() -> AIGraphCreationStepSchema {
        .init(stepType: .setInput,
              nodeId: OpenAISchema(type: .string),
              port: OpenAIGeneric(types: [OpenAISchema(type: .integer)],
                                  refs: [OpenAISchemaRef(ref: "LayerPorts")]),
              value: OpenAIGeneric(types: [
                OpenAISchema(type: .number),
                OpenAISchema(type: .string),
                OpenAISchema(type: .boolean),
                OpenAISchema(type: .object, additionalProperties: false)
              ]),
              valueType: OpenAISchemaRef(ref: "ValueType")
        )
    }
    
    static let structuredOutputsCodingKeys: Set<Step.CodingKeys> = [.stepType, .nodeId, .port, .value, .valueType]
    
    @MainActor
    func applyAction(document: StitchDocumentViewModel) -> StitchAIStepHandlingError? {
        let graph = document.visibleGraph
        
        do {
            let migratedPort = try self.port.convert(to: NodeIOPortType.self)
            let migratedValue = try self.value.migrate()
            
            let inputCoordinate = InputCoordinate(portType: migratedPort,
                                                  nodeId: self.nodeId)
            guard let input = graph.getInputObserver(coordinate: inputCoordinate) else {
                log("applyAction: could not apply setInput")
                // fatalErrorIfDebug()
                return .actionValidationError("Could not retrieve input \(inputCoordinate)")
            }
            
            // Use the common input-edit-committed function, so that we remove edges, block or unblock fields, etc.
            graph.inputEditCommitted(input: input,
                                     value: migratedValue,
                                     activeIndex: document.activeIndex)
        } catch let error as StitchAIStepHandlingError {
            return error
        } catch let error as SSKError {
            return .sskMigrationFailed(error)
        } catch {
            return .other(error)
        }
        
        return nil
    }
    
    func removeAction(graph: GraphState, document: StitchDocumentViewModel) {
        // Do nothing, assume node will be removed
    }
    
    func validate(createdNodes: [NodeId : PatchOrLayer]) -> Result<[NodeId: PatchOrLayer], StitchAIStepHandlingError> {
        // node must exist
        guard createdNodes.get(self.nodeId).isDefined else {
            log("areLLMStepsValid: Invalid .setInput: \(self)")
            return .failure(.actionValidationError("SetInput: Node \(self.nodeId.debugFriendlyId) does not yet exist"))
        }
        return .success(createdNodes)
    }
}

//struct StepActionEditJSNode {
//    static let stepType: StepType = .editJSNode
//    
//    var settings: JavaScriptNodeSettings
//}

// TODO: come back
//extension StepActionEditJSNode: StepActionable {
//    init(script: String,
//         inputDefinitions: [JavaScriptPortDefinition],
//         outputDefinitions: [JavaScriptPortDefinition]) {
//        self.init(settings: .init(script: script,
//                                  inputDefinitions: inputDefinitions,
//                                  outputDefinitions: outputDefinitions)
//        )
//    }
//    
//    var script: String {
//        self.settings.script
//    }
//    var inputDefinitions: [JavaScriptPortDefinition] {
//        self.settings.inputDefinitions
//    }
//    var outputDefinitions: [JavaScriptPortDefinition] {
//        self.settings.outputDefinitions
//    }
//    
//    static func fromStep(_ action: Step) -> Result<Self, StitchAIStepHandlingError> {
//        guard let settings = action.jsNodeSettings else {
//            print("JavaScript node: unable extract all requested data from: \(action)")
//            return .failure(.stepDecoding(.editJSNode, action))
//        }
//        
//        return .success(.init(script: script,
//                              inputDefinitions: inputs,
//                              outputDefinitions: outputs))
//    }
//    
//    static let structuredOutputsCodingKeys: Set<Step.CodingKeys> = [
//        .stepType, .script, .inputDefinitions, .outputDefinitions
//    ]
//    
//    var toStep: Step {
//        Step(stepType: Self.stepType,
//             script: script,
//             inputDefinitions: inputDefinitions.map(\.aiStep),
//             outputDefinitions: outputDefinitions.map(\.aiStep))
//    }
//    
//    static func createStructuredOutputs() -> AIGraphCreationStepSchema {
//        .init(stepType: .editJSNode,
//              script: OpenAISchema(type: .string),
//              inputDefinitions: OpenAISchemaRef(ref: "PortDefinitions"),
//              outputDefinitions: OpenAISchemaRef(ref: "PortDefinitions")
//        )
//    }
//    
//    func applyAction(document: StitchDocumentViewModel) -> StitchAIStepHandlingError? {
//        let graph = document.visibleGraph
//        
//        guard let nodeId = document.aiManager?.jsRequestNodeId,
//              let node = graph.getNode(nodeId),
//              let patchNode = node.patchNode else {
//            return .actionValidationError("StepActionEditJSNode.applyAction error: state missing")
//        }
//        
//        // Reset request
//        document.aiManager?.jsRequestNodeId = nil
//        
//        // Sets new data and recalculate
//        patchNode.processNewJavascript(response: self.settings)
//        
//        return nil
//    }
//    
//    func removeAction(graph: GraphState, document: StitchDocumentViewModel) {
//        // Nothing to do
//    }
//    
//    func validate(createdNodes: [NodeId : PatchOrLayer]) -> Result<[NodeId : PatchOrLayer], StitchAIStepHandlingError> {
//        // Nothing to do
//        return .success(createdNodes)
//    }
//    
//    func remapNodeIds(nodeIdMap: [StitchAIUUID : NodeId]) -> StepActionEditJSNode {
//        // Do nothing
//        return self
//    }
//}

extension StepActionable {
    var toPortCoordinate: CurrentStep.NodeIOCoordinate? {
        let step = self.toStep
        
        guard let nodeId = step.nodeId ?? step.toNodeId,
              let port = step.port else { return nil }
        
        return .init(portType: port, nodeId: nodeId.value)
    }
}
