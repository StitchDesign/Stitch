//
//  StepType.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/30/25.
//

import Foundation

// Type aliases for improved code readability
typealias LLMStepAction = Step
typealias LLMStepActions = [LLMStepAction]

// TODO: use several different data structures with more specific parameters,
// rather than a single data structure with tons of optional parameters
// TODO: make parameters more specific? e.g. `nodeName` should be `PatchOrLayer?`
// instead of `String?`


/// Enumeration of possible step types in the visual programming system
enum StepType: String, Equatable, Codable {
    case addNode = "add_node"
    case addLayerInput = "add_layer_input"
    case connectNodes = "connect_nodes"
    case changeNodeType = "change_node_type"
    case setInput = "set_input"
    
    var display: String {
        switch self {
        case .addNode:
            return "Add Node"
        case .addLayerInput:
            return "Add Layer Input"
        case .connectNodes:
            return "Connect Nodes"
        case .changeNodeType:
            return "Change Node Type"
        case .setInput:
            return "Set Input"
        }
    }
}
