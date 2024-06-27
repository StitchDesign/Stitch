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
    
    // empty string = we moved a patch node,
    // non-empty string = we moved a layer input/output/field
    // Non-empty Strings always represents LABELS
    let port: String
    
    // (position at end of movement - position at start of movement)
    let translation: LLMMoveNodeTranslation
}


// MARK: Set Input

struct LLMPortCoordinate: Equatable, Codable {
    let node: String
    
    // Always the LABEL of the input/output/field
    let port: String
}

struct LLMSetInputAction: Equatable, Encodable {
    let action: String = LLMActionNames.setInput.rawValue
    let field: LLMPortCoordinate
    let value: JSONFriendlyFormat
    let nodeType: String
}


// MARK: Add Edge

struct LLMAddEdge: Equatable, Codable {
    let action: String = LLMActionNames.addEdge.rawValue
    let from: LLMPortCoordinate
    let to: LLMPortCoordinate
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
