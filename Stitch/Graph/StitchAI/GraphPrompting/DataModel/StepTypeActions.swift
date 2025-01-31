//
//  StepTypeActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/30/25.
//

import Foundation
import SwiftUI

enum StepTypeActions: Equatable, Hashable, Codable {
    case addNode(StepActionAddNode)
    case addLayerInput(StepActionAddLayerInput)
    case connectNodes(StepActionConnectionAdded)
    case changeNodeType(StepActionChangeNodeType)
    case setInput(StepActionSetInput)
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

