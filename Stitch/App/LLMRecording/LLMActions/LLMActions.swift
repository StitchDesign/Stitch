//
//  LLMActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/25/24.
//

import Foundation

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
}

struct LLMMoveNode: Equatable, Codable {
    let action: String = LLMActionNames.moveNode.rawValue
    let node: String
    
    // empty string if we moved a patch node,
    // non-empty string if we moved a layer input/field.
    let port: String
    
    // (position at end of movement - position at start of movement)
    let translation: LLMMoveNodeTranslation
}


// MARK: Set Field

struct LLMAFieldCoordinate: Equatable, Codable {
    let node: String
    let port: String // can be key path or port number
    let field: Int
}

struct LLMSetFieldAction: Equatable, Codable {
    let action: String = LLMActionNames.setField.rawValue
    let field: LLMAFieldCoordinate
    let value: String
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
    let nodeType: NodeType
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
