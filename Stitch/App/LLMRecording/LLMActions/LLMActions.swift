//
//  LLMActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/25/24.
//

import Foundation
import StitchSchemaKit

// MARK: Add Node

// Used fo
struct LLMAddNode: Equatable, Codable {
    let action: String = LLMActionNames.addNode.rawValue
    // `node` for AddNode represents node kind's default node + some portion of its UI id
    let node: String
}


// MARK: Move Node

struct LLMMoveNodeTranslation: Equatable, Codable {
    let x: CGFloat
    let y: CGFloat
    
    var asCGSize: CGSize {
        .init(width: x, height: y)
    }
}

struct LLMMoveNode: Equatable, Codable {
    let action: String = LLMActionNames.moveNode.rawValue
    let node: String
    
    // empty string if we moved a patch node,
    // non-number string if we moved a layer input/field.
    // number string if we moved a layer output.
    let port: String
    
    // (position at end of movement - position at start of movement)
    let translation: LLMMoveNodeTranslation
}

func getCanvasId(llmNode: String,
                 llmPort: String,
                 _ mapping: LLMNodeIdMapping) -> CanvasItemId? {
    if let llmNodeId = llmNode.parseLLMNodeTitleId,
       let nodeId = mapping.get(llmNodeId) {
            
        if llmPort.isEmpty {
            return .node(nodeId)
        } else if let portType = llmPort.parseLLMPortAsPortType {
            switch portType {
            case .portIndex(let portId):
                return .layerOutputOnGraph(.init(portId: portId, nodeId: nodeId))
            case .keyPath(let layerInput):
                return .layerInputOnGraph(.init(node: nodeId,
                                                keyPath: layerInput))
            }
        }
    }
    
    return nil
}

extension String {
    
    // meant to be called on the .node property of an LLMAction
    func getNodeIdFromLLMNode(from mapping: LLMNodeIdMapping) -> NodeId? {
        if let llmNodeId = self.parseLLMNodeTitleId,
           let nodeId = mapping.get(llmNodeId) {
            return nodeId
        }
        return nil
    }
    
    var parseLLMPortAsPortType: NodeIOPortType? {
        let llmPort = self
        
        if let portId = Int.init(llmPort) {
            return .portIndex(portId)
        } else if let layerInput = llmPort.parseLLMPortAsLayerInputType {
            return .keyPath(layerInput)
        }
        return nil
    }
    
    var parseLLMPortAsLayerInputType: LayerInputType? {
        
        if let layerInput = LayerInputType.allCases.first(where: {
            $0.label() == self }) {
            return layerInput
        }
        return nil
    }
}

// MARK: Set Field

struct LLMAFieldCoordinate: Equatable, Codable {
    let node: String
    let port: String // can be key path or port number
    let field: Int
}

//struct LLMSetFieldAction: Equatable, Codable {
struct LLMSetFieldAction: Equatable, Encodable {
    let action: String = LLMActionNames.setField.rawValue
    let field: LLMAFieldCoordinate
    
    // put these together?
    let value: JSONFriendlyFormat
    let nodeType: String
}


// MARK: Add Edge

struct LLMAddEdgeCoordinate: Equatable, Codable {
    let node: String
    
    // number = Patch Node input or output, Layer Node output
    // string = Layer Node input
    let port: String
}

struct LLMAddEdge: Equatable, Codable {
    let action: String = LLMActionNames.addEdge.rawValue
    let from: LLMAddEdgeCoordinate
    let to: LLMAddEdgeCoordinate
}


// MARK: Change Node Type

struct LLMAChangeNodeTypeAction: Equatable, Codable {
    let action = LLMActionNames.changeNodeType.rawValue
    let node: String
    let nodeType: String
}

extension String {
    var parseLLMNodeType: NodeType? {
        // TODO: update NodeType rawValue so that we do not need to use `.display`
        NodeType.allCases.first { $0.display == self }
    }
}

// MARK: Add Layer Node Input/Output

struct LLMAddLayerInput: Equatable, Codable {
    let action = LLMActionNames.addLayerInput.rawValue
    let node: String
    let port: String // layer node input's label (long form)
}

struct LLMAddLayerOutput: Equatable, Codable {
    let action = LLMActionNames.addLayerOutput.rawValue
    let node: String
    let port: String // layer node input's label (long form)
}
