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
        case .addNode(let x):
            return StepActionAddNode.stepType
        case .addLayerInput(let x):
            return StepActionAddLayerInput.stepType
        case .connectNodes(let x):
            return StepActionConnectionAdded.stepType
        case .changeNodeType(let x):
            return StepActionChangeNodeType.stepType
        case .setInput(let x):
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
            fatalErrorIfDebug()
            return nil
        }
        
        switch stepType {
            
        case .addNode:
            guard let x = StepActionAddNode.fromStep(action) else {
                fatalErrorIfDebug()
                return nil
            }
            return .addNode(x)
            
        case .addLayerInput:
            guard let x = StepActionAddLayerInput.fromStep(action) else {
                fatalErrorIfDebug()
                return nil
            }
            return .addLayerInput(x)
            
        case .connectNodes:
            guard let x = StepActionConnectionAdded.fromStep(action) else {
                fatalErrorIfDebug()
                return nil
            }
            return .connectNodes(x)
        
        case .changeNodeType:
            guard let x = StepActionChangeNodeType.fromStep(action) else {
                fatalErrorIfDebug()
                return nil
            }
            return .changeNodeType(x)
        
        case .setInput:
            guard let x = StepActionSetInput.fromStep(action) else {
                fatalErrorIfDebug()
                return nil
            }
            return .setInput(x)
        }
    }
}

extension [StepTypeAction] {
    // Note: just some obvious validations; NOT a full validation; we can still e.g. create a connection from an output that doesn't exist etc.
    func areLLMStepsValid() -> Bool {
        
        // Need to update this *as we go*, so that we can confirm that e.g. connectNodes came after we created at least two different nodes
        var createdNodes = [NodeId: PatchOrLayer]()
        
        for step in self {
            
            switch step {
                
            case .addNode(let x):
                createdNodes.updateValue(x.nodeName, forKey: x.nodeId)
                
            case .changeNodeType(let x):
                // Must have a valid node type for the patch, and must be a patch
                guard let patch = createdNodes.get(x.nodeId)?.asNodeKind.getPatch,
                      patch.availableNodeTypes.contains(x.nodeType) else {
                    log("areLLMStepsValid: Invalid .changeNodeType: \(x)")
                    return false
                }
            
            case .addLayerInput(let x):
                // the layer node must exist already
                guard createdNodes.get(x.nodeId)?.asNodeKind.getLayer.isDefined ?? false else {
                    log("areLLMStepsValid: Invalid .addLayerInput: \(x)")
                    return false
                }
            
            case .connectNodes(let x):
                // the to-node and from-node must exist
                guard createdNodes.get(x.fromNodeId).isDefined,
                      createdNodes.get(x.toNodeId).isDefined else {
                    log("areLLMStepsValid: Invalid .connectNodes: \(x)")
                    return false
                }
            
            case .setInput(let x):
                // node must exist
                guard createdNodes.get(x.nodeId).isDefined else {
                    log("areLLMStepsValid: Invalid .setInput: \(x)")
                    return false
                }
            }
        } // for step in self
        
        // If we didn't hit any guard statements, then the steps passed these validations
        return true
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
    
    let fromPort: NodeIOPortType // integer or key path
    let fromNodeId: NodeId
    
    var toStep: Step {
        Step(
            stepType: Self.stepType.rawValue,
            port: .init(value: port.asLLMStepPort()),
            fromPort: .init(value: fromPort.asLLMStepPort()),
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
                     fromPort: NodeIOPortType.portIndex(fromPort),
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

