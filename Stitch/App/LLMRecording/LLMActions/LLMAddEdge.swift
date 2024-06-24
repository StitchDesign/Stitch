//
//  LLMAddEdge.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/12/24.
//

import Foundation

struct LLMAddEdgeCoordinate: Equatable, Codable {
    let node: String
    
    // number = Patch Node input or output, Layer Node output
    // string = Layer Node input
    let port: String
}

struct LLMAddEdge: Equatable, Codable {
    let action: String = "Add Edge"
    let from: LLMAddEdgeCoordinate
    let to: LLMAddEdgeCoordinate
}
