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

struct StepActionAddNode: Equatable, Hashable, Codable {
    static let stepType: StepType = .addNode
    
    var nodeId: NodeId
    var nodeName: PatchOrLayer
}


struct StepActionAddLayerInput: Equatable, Hashable, Codable {
    static let stepType = StepType.addLayerInput
    
    let nodeId: NodeId
    
    // can only ever be a layer-input
    let port: LayerInputPort // assumes .packed
}

struct StepActionConnectionAdded: Equatable, Hashable, Codable {
    static let stepType = StepType.connectNodes
    
    // effectively the 'to port'
    let port: NodeIOPortType // integer or key path
    let toNodeId: NodeId
    
    let fromPort: NodeIOPortType // integer or key path
    let fromNodeId: NodeId
}

struct StepActionChangeNodeType: Equatable, Hashable, Codable {
    static let stepType = StepType.changeNodeType
    
    var nodeId: NodeId
    var nodeType: NodeType
}

struct StepActionSetInput: Equatable, Hashable, Codable {
    static let stepType = StepType.setInput
    
    let nodeId: NodeId
    let port: NodeIOPortType // integer or key path
    let value: PortValue
    let nodeType: NodeType
}

