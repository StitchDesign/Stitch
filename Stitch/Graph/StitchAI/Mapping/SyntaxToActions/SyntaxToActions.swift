//
//  SyntaxToActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/23/25.
//

import SwiftUI
import OrderedCollections

// Start out with simple actions now; just want to test; can we create proper StepActions later

typealias StitchActions = [StitchAction]
typealias StitchActionOrderedSet = OrderedSet<StitchAction>

enum StitchAction: Equatable, Codable, Hashable {
    case createLayer(SACreateLayer)
    case setLayerInput(SASetLayerInput)
    case incomingEdge(SAIncomingEdge)
}

// create a layer, including its children
struct SACreateLayer: Equatable, Codable, Hashable {
    let id: String
    let name: String
    let children: [SACreateLayer]
}

// a manual value set in the layer input
struct SASetLayerInput: Equatable, Codable, Hashable {
    let name: String // the input which is receiving the
    let value: String // the manually-set value
}

// an edge coming into the layer input
struct SAIncomingEdge: Equatable, Codable, Hashable {
    let name: String // the input which is receiving the edge
}

func deriveStitchActions(_ viewNode: ViewNode) -> StitchActionOrderedSet {
    var actions = StitchActionOrderedSet()

    // Helper: Build the SACreateLayer tree for this node and its children.
    func buildCreateLayer(for node: ViewNode) -> SACreateLayer {
        SACreateLayer(
            id: node.id,
            name: node.name,
            children: node.children.map { buildCreateLayer(for: $0) }
        )
    }

    // 1. Every ViewNode → one SACreateLayer (with children).
    let createLayer = buildCreateLayer(for: viewNode)
    actions.append(.createLayer(createLayer))

    // 2. For each initializer argument in ViewNode.arguments:
    for arg in viewNode.arguments {
        switch arg.syntaxKind {
        case .literal:
            actions.append(.setLayerInput(SASetLayerInput(name: arg.label ?? "", value: arg.value)))
        default:
            actions.append(.incomingEdge(SAIncomingEdge(name: arg.label ?? "")))
        }
    }

    // 3. For each modifier in ViewNode.modifiers:
    for modifier in viewNode.modifiers {
        let allLiteral = modifier.arguments.allSatisfy {
            if case .literal = $0.syntaxKind { return true }
            return false
        }
        if allLiteral {
            // Emit ONE SASetLayerInput: name = modifier.kind.rawValue, value = joined literal list
            // Format: "label1: value1, value2"
            let modName = modifier.kind.rawValue
            let parts: [String] = modifier.arguments.map {
                if let label = $0.label, !label.isEmpty {
                    return "\(label): \($0.value)"
                } else {
                    return $0.value
                }
            }
            let joined = parts.joined(separator: ", ")
            actions.append(.setLayerInput(SASetLayerInput(name: modName, value: joined)))
        } else {
            // Emit ONE action per argument
            for arg in modifier.arguments {
                let actionName: String
                let modName = modifier.kind.rawValue
                if let label = arg.label, !label.isEmpty {
                    actionName = "\(modName).\(label)"
                } else {
                    actionName = modName
                }
                switch arg.syntaxKind {
                case .literal:
                    actions.append(.setLayerInput(SASetLayerInput(name: actionName, value: arg.value)))
                default:
                    actions.append(.incomingEdge(SAIncomingEdge(name: actionName)))
                }
            }
        }
    }

    // 4. Recurse into children (emit their actions in order).
    for child in viewNode.children {
        let childActions = deriveStitchActions(child)
        for act in childActions {
            actions.append(act)
        }
    }

    return actions
}
