//
//  StepTypeActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/30/25.
//

import Foundation
import SwiftUI

// See `StepType` enum
enum StepTypeAction: Equatable, Hashable, Codable {
    
    case addNode(StepActionAddNode)
    case connectNodes(StepActionConnectionAdded)
    case changeValueType(StepActionChangeValueType)
    case setInput(StepActionSetInput)
    
    var stepType: StepType {
        switch self {
        case .addNode:
            return StepActionAddNode.stepType
        case .connectNodes:
            return StepActionConnectionAdded.stepType
        case .changeValueType:
            return StepActionChangeValueType.stepType
        case .setInput:
            return StepActionSetInput.stepType
        }
    }
    
    func toStep() -> Step {
        switch self {
        case .addNode(let x):
            return x.toStep
        case .connectNodes(let x):
            return x.toStep
        case .changeValueType(let x):
            return x.toStep
        case .setInput(let x):
            return x.toStep
        }
    }
    
    static func fromStep(_ action: Step) throws -> Self {
        let stepType = action.stepType
        switch stepType {
            
        case .addNode:
            let x = try StepActionAddNode.fromStep(action)
            return .addNode(x)
            
        case .connectNodes:
            let x = try StepActionConnectionAdded.fromStep(action)
            return .connectNodes(x)
            
        case .changeValueType:
            let x = try StepActionChangeValueType.fromStep(action)
            return .changeValueType(x)
            
        case .setInput:
            let x = try StepActionSetInput.fromStep(action)
            return .setInput(x)
        }
    }
}

extension Step {
    func convertToType() throws -> any StepActionable {
        let stepType = self.stepType
        switch stepType {
            
        case .addNode:
            return try StepActionAddNode.fromStep(self)

        case .connectNodes:
            return try StepActionConnectionAdded.fromStep(self)
        
        case .changeValueType:
            return try StepActionChangeValueType.fromStep(self)
        
        case .setInput:
            return try StepActionSetInput.fromStep(self)
        }
    }
}

extension Array where Element == any StepActionable {
    // Note: just some obvious validations; NOT a full validation; we can still e.g. create a connection from an output that doesn't exist etc.
    // nil = valid
    func validateLLMSteps() throws {
                
        // Need to update this *as we go*, so that we can confirm that e.g. connectNodes came after we created at least two different nodes
        var createdNodes = [NodeId: PatchOrLayer]()
        
        for step in self {
            try step.validate(createdNodes: &createdNodes)
        } // for step in self
        
        let (depthMap, hasCycle) = self.calculateAINodesAdjacency()
        
        if hasCycle {
            throw StitchAIManagerError
                .actionValidationError("Had cycle")
        }
        
        guard depthMap.isDefined else {
            throw StitchAIManagerError
                .actionValidationError("Could not topologically order the graph")
        }
    }
    
    func calculateAINodesAdjacency() -> (depthMap: [UUID: Int]?,
                                         hasCycle: Bool) {
        let adjacency = AdjacencyCalculator()
        self.forEach {
            if let connectNodesAction = $0 as? StepActionConnectionAdded {
                adjacency.addEdge(from: connectNodesAction.fromNodeId, to: connectNodesAction.toNodeId)
            }
        }
        
        let (depthMap, hasCycle) = adjacency.computeDepth()
        
        if var depthMap = depthMap, !hasCycle {
            // If we did not have a cycle, also add those nodes which did not have a connection;
            // Node without connection = node with depth level 0
            self.nodesCreatedByLLMActions().forEach {
                if !depthMap.get($0).isDefined {
                    depthMap.updateValue(0, forKey: $0)
                }
            }
            return (depthMap, hasCycle)
            
        } else {
            return (depthMap, hasCycle)
        }
    }
}



// "Which properties from `Step` are actually needed by StepType = .addNode ?"

protocol StepActionable: Hashable, Codable {
    static var stepType: StepType { get }
        
    static func fromStep(_ action: Step) throws -> Self
    
    static func createStructuredOutputs() -> StitchAIStepSchema
    
    /// Lists each property tracked in OpenAI's structured outputs.
    static var structuredOutputsCodingKeys: Set<Step.CodingKeys> { get }
    
    var toStep: Step { get }
    
    @MainActor
    func applyAction(graph: GraphState) throws
    
    @MainActor
    func removeAction(graph: GraphState)
    
    func validate(createdNodes: inout [NodeId : PatchOrLayer]) throws
}

// See `createLLMStepAddNode`
struct StepActionAddNode: StepActionable {
    static let stepType: StepType = .addNode
    
    var nodeId: NodeId
    var nodeName: PatchOrLayer

    var toStep: Step {
        Step(stepType: Self.stepType,
             nodeId: nodeId,
             nodeName: nodeName)
    }
    
    static func fromStep(_ action: Step) throws -> Self {
        if let nodeId = action.nodeId?.value,
           let nodeKind = action.nodeName {
            return .init(nodeId: nodeId,
                         nodeName: nodeKind)
        }
        throw StitchAIManagerError.stepDecoding(Self.stepType, action)
    }
    
    static func createStructuredOutputs() -> StitchAIStepSchema {
        .init(stepType: .addNode,
              nodeId: OpenAISchema(type: .string),
              nodeName: OpenAISchemaRef(ref: "NodeName")
        )
    }
    
    static let structuredOutputsCodingKeys: Set<Step.CodingKeys> = [.stepType, .nodeId, .nodeName]
    
    func applyAction(graph: GraphState) throws {
        guard let _ = graph.documentDelegate?.nodeInserted(choice: self.nodeName.asNodeKind,
                                                          nodeId: self.nodeId) else {
            throw StitchAIManagerError.actionValidationError("Could not create node \(self.nodeId.debugFriendlyId) \(self.nodeName)")
        }
    }
    
    func removeAction(graph: GraphState) {
        graph.deleteNode(id: self.nodeId,
                         willDeleteLayerGroupChildren: true)
    }
    
    func validate(createdNodes: inout [NodeId : PatchOrLayer]) throws {
        createdNodes.updateValue(self.nodeName, forKey: self.nodeId)
    }
}

// See `createLLMStepConnectionAdded`
struct StepActionConnectionAdded: StepActionable {
    static let stepType = StepType.connectNodes
    
    // effectively the 'to port'
    let port: NodeIOPortType // integer or key path
    let toNodeId: NodeId
    
    let fromPort: Int //NodeIOPortType // integer or key path
    let fromNodeId: NodeId
    
    var toStep: Step {
        Step(
            stepType: Self.stepType,
            port: port,
            fromPort: fromPort,
            fromNodeId: fromNodeId,
            toNodeId: toNodeId
        )
    }
    
    static func fromStep(_ action: Step) throws -> Self {
        guard let fromNodeId = action.fromNodeId?.value,
              let toPort = action.port,
              let toNodeId = action.toNodeId?.value else {
            throw StitchAIManagerError.stepDecoding(Self.stepType, action)
        }

        // default to 0 for some legacy actions ?
        let fromPort = action.fromPort ?? 0
        
        return .init(port: toPort,
                     toNodeId: toNodeId,
                     fromPort: fromPort,
                     fromNodeId: fromNodeId)
    }
    
    static func createStructuredOutputs() -> StitchAIStepSchema {
        .init(stepType: .connectNodes,
              port: OpenAIGeneric(types: [OpenAISchema(type: .integer)],
                                  refs: [OpenAISchemaRef(ref: "LayerPorts")]),
              fromPort: OpenAISchema(type: .integer),
              fromNodeId: OpenAISchema(type: .string),
              toNodeId: OpenAISchema(type: .string)
        )
    }
    
    static let structuredOutputsCodingKeys: Set<Step.CodingKeys> = [.stepType, .port, .fromPort, .fromNodeId, .toNodeId]
    
    var inputPort: NodeIOCoordinate {
        .init(portType: self.port, nodeId: self.toNodeId)
    }
    
    func applyAction(graph: GraphState) throws {
        let edge: PortEdgeData = PortEdgeData(
            from: .init(portType: .portIndex(self.fromPort), nodeId: self.fromNodeId),
            to: self.inputPort)
        
        let _ = graph.edgeAdded(edge: edge)
        
        // Create canvas node if destination is layer
        if let fromNodeLocation = graph.getNodeViewModel(self.fromNodeId)?.patchCanvasItem?.position,
           let destinationNode = graph.getNodeViewModel(self.toNodeId),
           let layerNode = destinationNode.layerNode {
            guard let keyPath = self.port.keyPath else {
                // fatalErrorIfDebug()
                throw StitchAIManagerError.actionValidationError("expected layer node keypath but got: \(self.port)")
            }
            
            var position = fromNodeLocation
            position.x += 200
            
            let inputData = layerNode[keyPath: keyPath.layerNodeKeyPath]
            graph.layerInputAddedToGraph(node: destinationNode,
                                         input: inputData,
                                         coordinate: keyPath,
                                         position: position)
        }
    }
    
    func removeAction(graph: GraphState) {
        graph.removeEdgeAt(input: self.inputPort)
    }
    
    func validate(createdNodes: inout [NodeId : PatchOrLayer]) throws {
        let originNode = createdNodes.get(self.fromNodeId)
        let destinationNode = createdNodes.get(self.toNodeId)
        
        guard destinationNode.isDefined else {
            throw StitchAIManagerError
                .actionValidationError("ConnectNodes: Tried create a connection from node \(self.fromNodeId.debugFriendlyId) to \(self.toNodeId.debugFriendlyId), but the To Node does not yet exist")
        }
        
        guard let originNode = originNode else {
            throw StitchAIManagerError
                .actionValidationError("ConnectNodes: Tried create a connection from node \(self.fromNodeId.debugFriendlyId) to \(self.toNodeId.debugFriendlyId), but the From Node does not yet exist")
        }
        
        guard originNode.asNodeKind.isPatch else {
            throw StitchAIManagerError
                .actionValidationError("ConnectNodes: Tried create a connection from node \(self.fromNodeId.debugFriendlyId) to \(self.toNodeId.debugFriendlyId), but the From Node was a layer or group")
        }
    }
}

// See: `createLLMStepChangeValueType`
struct StepActionChangeValueType: StepActionable {
    static let stepType = StepType.changeValueType
    
    var nodeId: NodeId
    var valueType: NodeType
    
    var toStep: Step {
        Step(stepType: Self.stepType,
             nodeId: nodeId,
             valueType: valueType)
    }
    
    static func fromStep(_ action: Step) throws -> Self {
        if let nodeId = action.nodeId?.value,
           let valueType = action.valueType {
            return .init(nodeId: nodeId,
                         valueType: valueType)
        }
        
        throw StitchAIManagerError.stepDecoding(Self.stepType, action)
    }
    
    static func createStructuredOutputs() -> StitchAIStepSchema {
        .init(stepType: .changeValueType,
              nodeId: OpenAISchema(type: .string),
              valueType: OpenAISchemaRef(ref: "ValueType")
        )
    }
    
    static let structuredOutputsCodingKeys: Set<Step.CodingKeys> = [.stepType, .nodeId, .valueType]
    
    func applyAction(graph: GraphState) throws {
        // NodeType etc. for this patch was already validated in `[StepTypeAction].areValidLLMSteps`
        let _ = graph.nodeTypeChanged(nodeId: self.nodeId,
                                      newNodeType: self.valueType,
                                      activeIndex: graph.documentDelegate?.activeIndex ?? .init(.zero))
    }
    
    func removeAction(graph: GraphState) {
        // Do nothing, assume node will be removed
    }
    
    func validate(createdNodes: inout [NodeId : PatchOrLayer]) throws {
        guard let patch = createdNodes.get(self.nodeId)?.asNodeKind.getPatch else {
            throw StitchAIManagerError
                .actionValidationError("ChangeValueType: no patch for node \(self.nodeId.debugFriendlyId)")
        }
        
        guard patch.availableNodeTypes.contains(self.valueType) else {
            throw StitchAIManagerError
                .actionValidationError("ChangeValueType: invalid node type \(self.valueType.display) for patch \(patch.defaultDisplayTitle()) on node \(self.nodeId.debugFriendlyId)")
        }
    }
}

// See: `createLLMStepSetInput`
struct StepActionSetInput: StepActionable {
    static let stepType = StepType.setInput
    
    let nodeId: NodeId
    let port: NodeIOPortType // integer or key path
    let value: PortValue
    let valueType: NodeType
    
    // encoding
    var toStep: Step {
        Step(stepType: Self.stepType,
             nodeId: nodeId,
             port: port,
             value: value,
             valueType: value.toNodeType)
    }
    
    static func fromStep(_ action: Step) throws -> Self {
        if let nodeId = action.nodeId?.value,
           let port = action.port,
           let valueType = action.valueType,
           let value = action.value {
            return .init(nodeId: nodeId,
                         port: port,
                         value: value,
                         valueType: valueType)
        }
        
        throw StitchAIManagerError.stepDecoding(Self.stepType, action)
    }
    
    static func createStructuredOutputs() -> StitchAIStepSchema {
        .init(stepType: .setInput,
              nodeId: OpenAISchema(type: .string),
              port: OpenAIGeneric(types: [OpenAISchema(type: .integer)],
                                  refs: [OpenAISchemaRef(ref: "LayerPorts")]),
              value: OpenAIGeneric(types: [
                OpenAISchema(type: .number),
                OpenAISchema(type: .string),
                OpenAISchema(type: .boolean),
                OpenAISchema(type: .object)
              ]),
              valueType: OpenAISchemaRef(ref: "ValueType")
        )
    }
    
    static let structuredOutputsCodingKeys: Set<Step.CodingKeys> = [.stepType, .nodeId, .port, .value, .valueType]
    
    func applyAction(graph: GraphState) throws {
        let inputCoordinate = InputCoordinate(portType: self.port,
                                              nodeId: self.nodeId)
        guard let input = graph.getInputObserver(coordinate: inputCoordinate) else {
            log("applyAction: could not apply setInput")
            // fatalErrorIfDebug()
            throw StitchAIManagerError.actionValidationError("Could not retrieve input \(inputCoordinate)")
        }
        
        // Use the common input-edit-committed function, so that we remove edges, block or unblock fields, etc.
        graph.inputEditCommitted(input: input,
                                 value: self.value,
                                 activeIndex: graph.documentDelegate?.activeIndex ?? .init(.zero))
    }
    
    func removeAction(graph: GraphState) {
        // Do nothing, assume node will be removed
    }
    
    func validate(createdNodes: inout [NodeId : PatchOrLayer]) throws {
        // node must exist
        guard createdNodes.get(self.nodeId).isDefined else {
            log("areLLMStepsValid: Invalid .setInput: \(self)")
            throw StitchAIManagerError
                .actionValidationError("SetInput: Node \(self.nodeId.debugFriendlyId) does not yet exist")
        }
    }
}
