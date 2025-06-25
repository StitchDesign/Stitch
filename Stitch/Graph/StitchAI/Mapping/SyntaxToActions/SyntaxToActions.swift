//
//  SyntaxToActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/23/25.
//

import SwiftUI
import OrderedCollections

// MARK: 'actions' just in the sense of being something our VPL can consume

typealias VPLLayerConcepts = [VPLLayerConcept]
typealias VPLLayerConceptOrderedSet = OrderedSet<VPLLayerConcept>

enum VPLLayerConcept: Equatable, Codable, Hashable {
    case layer(VPLLayer)
    case layerInputSet(VPLLayerInputSet)
    case incomingEdge(VPLIncomingEdge)
}

// create a layer, including its children
struct VPLLayer: Equatable, Codable, Hashable {
    let id: String // TODO: should be UUID
    let name: Layer
    let children: [VPLLayer]
}

/// A concrete, typed mapping from a SwiftUI modifier (or initialiser label)
/// to a value in the visual‑programming layer.
struct VPLLayerInputSet: Equatable, Codable, Hashable {
    let kind: LayerInputPort
    
    // TODO: JUNE 24: use PortValue instead of String; reuse parsing logic from StepAction parsing etc. ?
    // let value: PortValue  // literal the user entered
    let value: String  // literal the user entered
}

// an edge coming into the layer input
struct VPLIncomingEdge: Equatable, Codable, Hashable {
    let name: LayerInputPort // the input which is receiving the edge
}

func deriveStitchActions(_ viewNode: ViewNode) -> VPLLayerConceptOrderedSet {
    var actions = VPLLayerConceptOrderedSet()

    // 1. Every ViewNode → one SACreateLayer (with children).
    if let createdLayer = viewNode.deriveCreateLayerAction() {
        actions.append(.layer(createdLayer))
        
        // 2. For each initializer argument in ViewNode.arguments:
        // 3. For each modifier in ViewNode.modifiers:
        actions.append(
            contentsOf: viewNode.deriveSetInputAndIncomingEdgeActions(createdLayer.name)
        )
        
        // 4. Recurse into children (emit their actions in order).
        for child in viewNode.children {
            let childActions = deriveStitchActions(child)
            for act in childActions {
                actions.append(act)
            }
        }
    } else {
        // if we can't create the layer, then we can't (or shouldn't) process its constructor-args, modifiers and children
        log("deriveStitchActions: Could not create layer for view node. Name: \(viewNode.name), viewNode: \(viewNode)")
    }
    
    return actions
}
