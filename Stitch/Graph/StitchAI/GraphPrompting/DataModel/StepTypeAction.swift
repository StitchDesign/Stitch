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
    
    static func fromStep(_ action: Step) -> Self? {
        guard let stepType = action.parseStepType else {
//            fatalErrorIfDebug()
            log("StepTypeAction.fromStep: could not create parse Step into StepTypeAction, please retry?: action: \(action)")
            return nil
        }
        
        switch stepType {
            
        case .addNode:
            guard let x = StepActionAddNode.fromStep(action) else {
//                fatalErrorIfDebug()
                log("StepTypeAction.fromStep: could not create parse Step into StepTypeAction, please retry?: action: \(action)")
                return nil
            }
            return .addNode(x)
            
        case .addLayerInput:
            guard let x = StepActionAddLayerInput.fromStep(action) else {
//                fatalErrorIfDebug()
                log("StepTypeAction.fromStep: could not create parse Step into StepTypeAction, please retry?: action: \(action)")
                return nil
            }
            return .addLayerInput(x)
            
        case .connectNodes:
            guard let x = StepActionConnectionAdded.fromStep(action) else {
//                fatalErrorIfDebug()
                log("StepTypeAction.fromStep: could not create parse Step into StepTypeAction, please retry?: action: \(action)")
                return nil
            }
            return .connectNodes(x)
        
        case .changeNodeType:
            guard let x = StepActionChangeNodeType.fromStep(action) else {
//                fatalErrorIfDebug()
                log("StepTypeAction.fromStep: could not create parse Step into StepTypeAction, please retry?: action: \(action)")
                return nil
            }
            return .changeNodeType(x)
        
        case .setInput:
            guard let x = StepActionSetInput.fromStep(action) else {
//                fatalErrorIfDebug()
                log("StepTypeAction.fromStep: could not create parse Step into StepTypeAction, please retry?: action: \(action)")
                return nil
            }
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

// See `createLLMStepAddNode`
struct StepActionAddNode: Equatable, Hashable, Codable {
    static let stepType: StepType = .addNode
    
    var nodeId: NodeId
    var nodeName: PatchOrLayer

    var toStep: Step {
        Step(stepType: Self.stepType.rawValue,
             nodeId: nodeId.description,
             nodeName: nodeName.asNodeKind.asLLMStepNodeName)
    }
    
    static func fromStep(_ action: Step) -> Self? {
        if let nodeId = action.parseNodeId,
           let nodeKind = action.parseNodeKind() {
            return .init(nodeId: nodeId,
                         nodeName: nodeKind)
        }
        return nil
    }
}

// See `createLLMStepAddLayerInput`
struct StepActionAddLayerInput: Equatable, Hashable, Codable {
    static let stepType = StepType.addLayerInput
    
    let nodeId: NodeId
    
    // can only ever be a layer-input
    let port: LayerInputPort // assumes .packed
    
    var toStep: Step {
        Step(stepType: Self.stepType.rawValue,
             nodeId: nodeId.description,
             nodeType: port.asLLMStepPort)
    }
    
    static func fromStep(_ action: Step) -> Self? {
        guard let nodeId = action.parseNodeId,
              let layerInput = action.parsePort()?.keyPath?.layerInput else {
            return nil
        }
        
        return .init(nodeId: nodeId, port: layerInput)
    }
}

// See `createLLMStepConnectionAdded`
struct StepActionConnectionAdded: Equatable, Hashable, Codable {
    static let stepType = StepType.connectNodes
    
    // effectively the 'to port'
    let port: NodeIOPortType // integer or key path
    let toNodeId: NodeId
    
    let fromPort: Int //NodeIOPortType // integer or key path
    let fromNodeId: NodeId
    
    var toStep: Step {
        Step(
            stepType: Self.stepType.rawValue,
            port: .init(value: port.asLLMStepPort()),
            fromPort: .init(value: String(fromPort)),
            fromNodeId: fromNodeId.uuidString,
            toNodeId: toNodeId.uuidString
        )
    }
    
    static func fromStep(_ action: Step) -> Self? {
        guard let fromNodeId = action.fromNodeId?.parseNodeId,
              let toPort: NodeIOPortType = action.parsePort(),
              let toNodeId = action.toNodeId?.parseNodeId else {
            return nil
        }

        // default to 0 for some legacy actions ?
        let fromPort = Int(action.fromPort?.value ?? "0") ?? 0
        
        return .init(port: toPort,
                     toNodeId: toNodeId,
                     fromPort: fromPort,
                     fromNodeId: fromNodeId)
    }
}

// See: `createLLMStepChangeNodeType`
struct StepActionChangeNodeType: Equatable, Hashable, Codable {
    static let stepType = StepType.changeNodeType
    
    var nodeId: NodeId
    var nodeType: NodeType
    
    var toStep: Step {
        Step(stepType: Self.stepType.rawValue,
             nodeId: nodeId.description,
             nodeType: nodeType.asLLMStepNodeType)
    }
    
    static func fromStep(_ action: Step) -> Self? {
        if let nodeId = action.parseNodeId,
           let nodeType = action.parseNodeType() {
            return .init(nodeId: nodeId,
                         nodeType: nodeType)
        }
        
        return nil
    }
}

// See: `createLLMStepSetInput`
struct StepActionSetInput: Equatable, Hashable, Codable {
    static let stepType = StepType.setInput
    
    let nodeId: NodeId
    let port: NodeIOPortType // integer or key path
    let value: PortValue
    let nodeType: NodeType
    
    var toStep: Step {
        Step(stepType: Self.stepType.rawValue,
             nodeId: nodeId.description,
             port: .init(value: port.asLLMStepPort()),
             value: value.llmFriendlyDisplay,
             nodeType: value.toNodeType.asLLMStepNodeType)
    }
    
    static func fromStep(_ action: Step) -> Self? {
        if let nodeId = action.parseNodeId,
           let port = action.parsePort(),
           let nodeType = action.parseNodeType(),
           let value = action.parseValueForSetInput(nodeType: nodeType) {
            return .init(nodeId: nodeId,
                         port: port,
                         value: value,
                         nodeType: nodeType)
        }
        
        return nil
    }
}

