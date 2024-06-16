//
//  LLMSetField.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/12/24.
//

import Foundation

struct LLMAFieldCoordinate: Equatable, Codable {
    let node: String
    let port: String // can be key path or port number
    let field: Int
}

struct LLMSetFieldAction: Equatable, Codable {
    let action: String = "Set Field"
    let field: LLMAFieldCoordinate
    let value: String
    let nodeType: String
}
