//
//  LLMAddNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/12/24.
//

import Foundation

struct LLMAddNode: Equatable, Codable {
    let action: String = "Add Node"
    // `node` for AddNode represents node kind's default node + some portion of its UI id
    let node: String
}
