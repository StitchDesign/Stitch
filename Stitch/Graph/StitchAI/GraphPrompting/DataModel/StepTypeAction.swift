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
    case addLayerInput(StepActionAddLayerInput)
    case connectNodes(StepActionConnectionAdded)
    case changeNodeType(StepActionChangeNodeType)
    case setInput(StepActionSetInput)
    
    var stepType: StepType {
        switch self {
        case .addNode:
            return StepActionAddNode.stepType
        case .addLayerInput:
            return StepActionAddLayerInput.stepType
        case .connectNodes:
            return StepActionConnectionAdded.stepType
        case .changeNodeType:
            return StepActionChangeNodeType.stepType
        case .setInput:
            return StepActionSetInput.stepType
        }
    }
    
    func toStep() -> Step {
        switch self {
        case .addNode(let x):
            return x.toStep
        case .addLayerInput(let x):
            return x.toStep
        case .connectNodes(let x):
            return x.toStep
        case .changeNodeType(let x):
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
            
        case .addLayerInput:
            let x = try StepActionAddLayerInput.fromStep(action)
            return .addLayerInput(x)
            
        case .connectNodes:
            let x = try StepActionConnectionAdded.fromStep(action)
            return .connectNodes(x)
        
        case .changeNodeType:
            let x = try StepActionChangeNodeType.fromStep(action)
            return .changeNodeType(x)
        
        case .setInput:
            let x = try StepActionSetInput.fromStep(action)
            return .setInput(x)
        }
    }
}

struct LLMActionsInvalidMessage: Equatable, Hashable {
    let value: String
    
    init(_ value: String) {
        self.value = value
    }
}

extension [StepTypeAction] {
    // Note: just some obvious validations; NOT a full validation; we can still e.g. create a connection from an output that doesn't exist etc.
    // nil = valid
    func areLLMStepsValid() -> LLMActionsInvalidMessage? {
                
        // Need to update this *as we go*, so that we can confirm that e.g. connectNodes came after we created at least two different nodes
        var createdNodes = [NodeId: PatchOrLayer]()
        
        for step in self {
            
            switch step {
                
            case .addNode(let x):
                createdNodes.updateValue(x.nodeName, forKey: x.nodeId)
                
            case .changeNodeType(let x):
                guard let patch = createdNodes.get(x.nodeId)?.asNodeKind.getPatch else {
                    return .init("ChangeNodeType: no patch for node \(x.nodeId.debugFriendlyId)")
                }
                
                guard patch.availableNodeTypes.contains(x.nodeType) else {
                    return .init("ChangeNodeType: invalid node type \(x.nodeType.display) for patch \(patch.defaultDisplayTitle()) on node \(x.nodeId.debugFriendlyId)")
                }
            
            case .addLayerInput(let x):
                // the layer node must exist already
                guard createdNodes.get(x.nodeId)?.asNodeKind.getLayer.isDefined ?? false else {
                    return .init("AddLayerInput: layer node \(x.nodeId.debugFriendlyId) does not exist yet")
                }
            
            case .connectNodes(let x):
                let originNode = createdNodes.get(x.fromNodeId)
                let destinationNode = createdNodes.get(x.toNodeId)
                
                guard destinationNode.isDefined else {
                    return .init("ConnectNodes: Tried create a connection from node \(x.fromNodeId.debugFriendlyId) to \(x.toNodeId.debugFriendlyId), but the To Node does not yet exist")
                }
                
                guard let originNode = originNode else {
                    return .init("ConnectNodes: Tried create a connection from node \(x.fromNodeId.debugFriendlyId) to \(x.toNodeId.debugFriendlyId), but the From Node does not yet exist")
                }
                
                guard originNode.asNodeKind.isPatch else {
                    return .init("ConnectNodes: Tried create a connection from node \(x.fromNodeId.debugFriendlyId) to \(x.toNodeId.debugFriendlyId), but the From Node was a layer or group")
                }
            
            case .setInput(let x):
                // node must exist
                guard createdNodes.get(x.nodeId).isDefined else {
                    log("areLLMStepsValid: Invalid .setInput: \(x)")
                    return .init("SetInput: Node \(x.nodeId.debugFriendlyId) does not yet exist")
                }
            }
        } // for step in self
        
        let (depthMap, hasCycle) = calculateAINodesAdjacency(self)
        
        if hasCycle {
            return .init("Had cycle")
        }
        
        guard depthMap.isDefined else {
            return .init("Could not topologically order the graph")
        }
        
        // If we didn't hit any guard statements, then the steps passed these validations
        // nil = no error! So we're valid
        return nil
    }
}

func calculateAINodesAdjacency(_ actions: [StepTypeAction]) -> (depthMap: [UUID: Int]?,
                                                                hasCycle: Bool)  {
    let adjacency = AdjacencyCalculator()
    actions.forEach {
        if case let .connectNodes(x) = $0 {
            adjacency.addEdge(from: x.fromNodeId, to: x.toNodeId)
        }
    }
    
    let (depthMap, hasCycle) = adjacency.computeDepth()
    
    if var depthMap = depthMap, !hasCycle {
        // If we did not have a cycle, also add those nodes which did not have a connection;
        // Node without connection = node with depth level 0
        actions.nodesCreatedByLLMActions().forEach {
            if !depthMap.get($0).isDefined {
                depthMap.updateValue(0, forKey: $0)
            }
        }
        return (depthMap, hasCycle)
        
    } else {
        return (depthMap, hasCycle)
    }
}


// "Which properties from `Step` are actually needed by StepType = .addNode ?"

protocol StepActionable: Hashable, Codable {
    static var stepType: StepType { get }
    
    static func fromStep(_ action: Step) throws -> Self
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
}

// See `createLLMStepAddLayerInput`
struct StepActionAddLayerInput: StepActionable {
    static let stepType = StepType.addLayerInput
    
    let nodeId: NodeId
    
    // can only ever be a layer-input
    let port: LayerInputPort // assumes .packed
    
    var toStep: Step {
        Step(stepType: Self.stepType,
             nodeId: nodeId,
             port: NodeIOPortType.keyPath(.init(layerInput: port,
                                                portType: .packed)))
    }
    
    static func fromStep(_ action: Step) throws -> Self {
        guard let nodeId = action.nodeId?.value,
              let layerInput = action.port?.keyPath?.layerInput else {
            throw StitchAIManagerError.stepDecoding(Self.stepType, action)
        }
        
        return .init(nodeId: nodeId,
                     port: layerInput)
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
        let fromPort = action.fromPort?.value ?? 0
        
        return .init(port: toPort,
                     toNodeId: toNodeId,
                     fromPort: fromPort,
                     fromNodeId: fromNodeId)
    }
}

// See: `createLLMStepChangeNodeType`
struct StepActionChangeNodeType: StepActionable {
    static let stepType = StepType.changeNodeType
    
    var nodeId: NodeId
    var nodeType: NodeType
    
    var toStep: Step {
        Step(stepType: Self.stepType,
             nodeId: nodeId,
             nodeType: nodeType)
    }
    
    static func fromStep(_ action: Step) throws -> Self {
        if let nodeId = action.nodeId?.value,
           let nodeType = action.nodeType {
            return .init(nodeId: nodeId,
                         nodeType: nodeType)
        }
        
        throw StitchAIManagerError.stepDecoding(Self.stepType, action)
    }
}

// See: `createLLMStepSetInput`
struct StepActionSetInput: StepActionable {
    static let stepType = StepType.setInput
    
    let nodeId: NodeId
    let port: NodeIOPortType // integer or key path
    let value: PortValue
    let nodeType: NodeType
    
    // encoding
    var toStep: Step {
        Step(stepType: Self.stepType,
             nodeId: nodeId,
             port: port,
             value: value,
             nodeType: value.toNodeType)
    }
    
    static func fromStep(_ action: Step) throws -> Self {
        if let nodeId = action.nodeId?.value,
           let port = action.port,
           let nodeType = action.nodeType,
           let value = action.value {
            return .init(nodeId: nodeId,
                         port: port,
                         value: value,
                         nodeType: nodeType)
        }
        
        throw StitchAIManagerError.stepDecoding(Self.stepType, action)
    }
}

