//
//  LLMChangeNodeType.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/13/24.
//

import Foundation
import StitchSchemaKit

struct LLMAChangeNodeTypeAction: Equatable, Codable {
    let action = "Change Node Type"
    let node: String
    let nodeType: NodeType
}
