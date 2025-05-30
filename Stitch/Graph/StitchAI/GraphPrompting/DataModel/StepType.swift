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
    case connectNodes = "connect_nodes"
    case changeValueType = "change_value_type"
    case setInput = "set_input"
    case sidebarGroupCreated = "sidebar_group_created"
    
    var display: String {
        switch self {
        case .addNode:
            return "Add Node"
        case .connectNodes:
            return "Connect Nodes"
        case .changeValueType:
            return "Change Node Type"
        case .setInput:
            return "Set Input"
        case .sidebarGroupCreated:
            return "Create Sidebar Group"
        }
    }
    
    var introducesNewNode: Bool {
        switch self {
        case .addNode, .sidebarGroupCreated:
            return true
        case .connectNodes, .changeValueType, .setInput:
            return false
        }
    }
}


